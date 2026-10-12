using System;
using System.Collections.Generic;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class PurchaseOrderController : ControllerBase
    {
        private readonly IPurchaseOrderService _service;
        private readonly ILogger<PurchaseOrderController> _logger;

        public PurchaseOrderController(IPurchaseOrderService service, ILogger<PurchaseOrderController> logger)
        {
            _service = service ?? throw new ArgumentNullException(nameof(service));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        private string? GetCurrentUserName()
        {
            var username = User.FindFirst(ClaimTypes.Name)?.Value 
                ?? User.Identity?.Name;
            return string.IsNullOrWhiteSpace(username) ? null : username.Trim();
        }

        /// <summary>
        /// GET api/purchaseorder
        /// Returns paged and filtered purchase order list.
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetPurchaseOrders([FromQuery] PurchaseOrderFilterRequest filter)
        {
            var result = await _service.GetPurchaseOrdersAsync(filter ?? new PurchaseOrderFilterRequest());
            return Ok(ApiResponse<PurchaseOrderPagedResult<PurchaseOrderHeaderDto>>.Ok(result));
        }

        /// <summary>
        /// GET api/purchaseorder/by-no?poNo=...
        /// Returns full purchase order details by PO number via query string (immune to URL slash issues).
        /// </summary>
        [HttpGet("by-no")]
        public async Task<IActionResult> GetPurchaseOrderByQuery([FromQuery] string poNo)
        {
            if (string.IsNullOrWhiteSpace(poNo))
            {
                return BadRequest(ApiResponse<PurchaseOrderHeaderDto>.Fail("Purchase order number is required."));
            }
            var po = await _service.GetPurchaseOrderByNoAsync(poNo.Trim());
            if (po == null)
            {
                return NotFound(ApiResponse<PurchaseOrderHeaderDto>.Fail($"Purchase Order '{poNo}' was not found."));
            }
            return Ok(ApiResponse<PurchaseOrderHeaderDto>.Ok(po));
        }

        /// <summary>
        /// GET api/purchaseorder/{**poNo}
        /// Returns full purchase order details by PO number.
        /// </summary>
        [HttpGet("{**poNo}")]
        public async Task<IActionResult> GetPurchaseOrder(string poNo)
        {
            if (string.IsNullOrWhiteSpace(poNo))
            {
                return BadRequest(ApiResponse<PurchaseOrderHeaderDto>.Fail("Purchase order number is required."));
            }
            var po = await _service.GetPurchaseOrderByNoAsync(poNo.Trim());
            if (po == null)
            {
                return NotFound(ApiResponse<PurchaseOrderHeaderDto>.Fail($"Purchase Order '{poNo}' was not found."));
            }
            return Ok(ApiResponse<PurchaseOrderHeaderDto>.Ok(po));
        }

        /// <summary>
        /// GET api/purchaseorder/lookups
        /// Returns dropdowns, initial defaults, and autocomplete suggestions for PO form.
        /// </summary>
        [HttpGet("lookups")]
        public async Task<IActionResult> GetLookups()
        {
            var lookups = await _service.GetLookupsAsync();
            return Ok(ApiResponse<PurchaseOrderLookupsDto>.Ok(lookups));
        }

        /// <summary>
        /// GET api/purchaseorder/suppliers
        /// Server-side debounced search for suppliers / creditors.
        /// </summary>
        [HttpGet("suppliers")]
        public async Task<IActionResult> GetSuppliers([FromQuery] string search = "", [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
        {
            var result = await _service.GetSuppliersLookupAsync(search, page, pageSize);
            return Ok(ApiResponse<PurchaseOrderPagedResult<SupplierLookupDto>>.Ok(result));
        }

        /// <summary>
        /// GET api/purchaseorder/items
        /// Server-side debounced search for catalog items.
        /// </summary>
        [HttpGet("items")]
        public async Task<IActionResult> GetItems([FromQuery] string search = "", [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
        {
            var result = await _service.GetItemsLookupAsync(search, page, pageSize);
            return Ok(ApiResponse<PurchaseOrderPagedResult<ItemLookupDto>>.Ok(result));
        }

        /// <summary>
        /// GET api/purchaseorder/item-merges/{itemCode}
        /// Returns lot/merge numbers and makers for an item.
        /// </summary>
        [HttpGet("item-merges/{itemCode}")]
        public async Task<IActionResult> GetItemMerges(string itemCode)
        {
            var merges = await _service.GetItemMergesAsync(itemCode);
            return Ok(ApiResponse<List<ItemMergeLookupDto>>.Ok(merges));
        }

        /// <summary>
        /// GET api/purchaseorder/shades
        /// Returns active shades list.
        /// </summary>
        [HttpGet("shades")]
        public async Task<IActionResult> GetShades()
        {
            var shades = await _service.GetShadesAsync();
            return Ok(ApiResponse<List<string>>.Ok(shades));
        }

        /// <summary>
        /// GET api/purchaseorder/check-lock?date=...
        /// Checks if a date is locked in LOCKDATAMST.
        /// </summary>
        [HttpGet("check-lock")]
        public async Task<IActionResult> CheckLock([FromQuery] DateTime date)
        {
            var isLocked = await _service.IsDateLockedAsync(date);
            return Ok(ApiResponse<bool>.Ok(isLocked, isLocked ? "Date is locked." : "Date is open."));
        }

        /// <summary>
        /// POST api/purchaseorder
        /// Creates or updates a Purchase Order inside an atomic database transaction.
        /// </summary>
        [HttpPost]
        public async Task<IActionResult> SavePurchaseOrder([FromBody] PurchaseOrderSaveRequest request)
        {
            var username = GetCurrentUserName();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<string>.Fail("Authenticated user identity is required."));
            }

            try
            {
                var poNo = await _service.SavePurchaseOrderAsync(request, username);
                return Ok(ApiResponse<string>.Ok(poNo, $"Purchase Order '{poNo}' saved successfully."));
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "Business rule violation when saving PO: {Message}", ex.Message);
                return BadRequest(ApiResponse<string>.Fail(ex.Message));
            }
            catch (ArgumentException ex)
            {
                _logger.LogWarning(ex, "Validation error when saving PO: {Message}", ex.Message);
                return BadRequest(ApiResponse<string>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Server error while saving Purchase Order");
                return StatusCode(500, ApiResponse<string>.Fail("Failed to save Purchase Order. An unexpected server error occurred."));
            }
        }

        /// <summary>
        /// DELETE api/purchaseorder/{poNo}
        /// Deletes a Purchase Order if not approved or received.
        /// </summary>
        [HttpDelete("{poNo}")]
        public async Task<IActionResult> DeletePurchaseOrder(string poNo)
        {
            var username = GetCurrentUserName();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<string>.Fail("Authenticated user identity is required."));
            }

            try
            {
                var success = await _service.DeletePurchaseOrderAsync(poNo, username);
                if (!success)
                {
                    return BadRequest(ApiResponse<bool>.Fail($"Could not delete Purchase Order '{poNo}'."));
                }
                return Ok(ApiResponse<bool>.Ok(true, $"Purchase Order '{poNo}' deleted successfully."));
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(ApiResponse<bool>.Fail(ex.Message));
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "Business rule violation when deleting PO: {Message}", ex.Message);
                return BadRequest(ApiResponse<bool>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Server error while deleting Purchase Order '{PoNo}'", poNo);
                return StatusCode(500, ApiResponse<bool>.Fail("Failed to delete Purchase Order. An unexpected server error occurred."));
            }
        }
    }
}
