using System;
using System.Collections.Generic;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SalesOrderController : ControllerBase
    {
        private readonly ISalesOrderService _service;
        private readonly ILogger<SalesOrderController> _logger;

        public SalesOrderController(ISalesOrderService service, ILogger<SalesOrderController> logger)
        {
            _service = service ?? throw new ArgumentNullException(nameof(service));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        private string GetCurrentUserName()
        {
            var username = User.FindFirst(ClaimTypes.Name)?.Value 
                ?? User.FindFirst("unique_name")?.Value
                ?? User.FindFirst("sub")?.Value
                ?? User.Identity?.Name;
            return string.IsNullOrWhiteSpace(username) ? "ADMIN" : username.Trim();
        }

        /// <summary>
        /// GET api/salesorder
        /// Returns paged and filtered sales order list.
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetSalesOrders([FromQuery] SalesOrderFilterRequest filter)
        {
            var result = await _service.GetSalesOrdersAsync(filter ?? new SalesOrderFilterRequest());
            return Ok(ApiResponse<SalesOrderPagedResult<SalesOrderHeaderDto>>.Ok(result));
        }

        /// <summary>
        /// GET api/salesorder/by-no?soNo=...
        /// Returns full sales order details by SO number via query string (immune to URL slash issues).
        /// </summary>
        [HttpGet("by-no")]
        public async Task<IActionResult> GetSalesOrderByQuery([FromQuery] string soNo)
        {
            if (string.IsNullOrWhiteSpace(soNo))
            {
                return BadRequest(ApiResponse<SalesOrderHeaderDto>.Fail("Sales order number is required."));
            }
            var cleanSo = Uri.UnescapeDataString(soNo).Trim();
            var so = await _service.GetSalesOrderByNoAsync(cleanSo);
            if (so == null)
            {
                return NotFound(ApiResponse<SalesOrderHeaderDto>.Fail($"Sales Order '{cleanSo}' was not found."));
            }
            return Ok(ApiResponse<SalesOrderHeaderDto>.Ok(so));
        }

        /// <summary>
        /// GET api/salesorder/{**soNo}
        /// Returns full sales order details by SO number.
        /// </summary>
        [HttpGet("{**soNo}")]
        public async Task<IActionResult> GetSalesOrder(string soNo)
        {
            if (string.IsNullOrWhiteSpace(soNo))
            {
                return BadRequest(ApiResponse<SalesOrderHeaderDto>.Fail("Sales order number is required."));
            }
            var cleanSo = Uri.UnescapeDataString(soNo).Trim();
            var so = await _service.GetSalesOrderByNoAsync(cleanSo);
            if (so == null)
            {
                return NotFound(ApiResponse<SalesOrderHeaderDto>.Fail($"Sales Order '{cleanSo}' was not found."));
            }
            return Ok(ApiResponse<SalesOrderHeaderDto>.Ok(so));
        }

        /// <summary>
        /// GET api/salesorder/lookups
        /// Returns dropdowns, initial defaults, and next sequence for Sales Order form.
        /// </summary>
        [HttpGet("lookups")]
        public async Task<IActionResult> GetLookups()
        {
            var lookups = await _service.GetLookupsAsync();
            return Ok(ApiResponse<SalesOrderLookupsDto>.Ok(lookups));
        }

        /// <summary>
        /// GET api/salesorder/customers
        /// Server-side debounced search for customers / debtors from PARTYMST.
        /// </summary>
        [HttpGet("customers")]
        public async Task<IActionResult> GetCustomers([FromQuery] string search = "", [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
        {
            var result = await _service.GetCustomersLookupAsync(search, page, pageSize);
            return Ok(ApiResponse<SalesOrderPagedResult<CustomerLookupDto>>.Ok(result));
        }

        /// <summary>
        /// GET api/salesorder/items
        /// Server-side debounced search for catalog items from ITEMMST.
        /// </summary>
        [HttpGet("items")]
        public async Task<IActionResult> GetItems([FromQuery] string search = "", [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
        {
            var result = await _service.GetItemsLookupAsync(search, page, pageSize);
            return Ok(ApiResponse<SalesOrderPagedResult<SalesOrderItemLookupDto>>.Ok(result));
        }

        /// <summary>
        /// GET api/salesorder/remarks?query=...
        /// Suggestion lookup for historical remarks.
        /// </summary>
        [HttpGet("remarks")]
        public async Task<IActionResult> GetRemarks([FromQuery] string query = "")
        {
            var remarks = await _service.GetRemarksLookupAsync(query);
            return Ok(ApiResponse<List<string>>.Ok(remarks));
        }

        /// <summary>
        /// GET api/salesorder/check-lock?date=...
        /// Checks if a date is locked in LOCKDATAMST.
        /// </summary>
        [HttpGet("check-lock")]
        public async Task<IActionResult> CheckLock([FromQuery] DateTime date)
        {
            var isLocked = await _service.IsDateLockedAsync(date);
            return Ok(ApiResponse<bool>.Ok(isLocked, isLocked ? "Date is locked." : "Date is open."));
        }

        /// <summary>
        /// POST api/salesorder
        /// Creates or updates a Sales Order inside an atomic database transaction.
        /// </summary>
        [HttpPost]
        public async Task<IActionResult> SaveSalesOrder([FromBody] SalesOrderSaveRequest request)
        {
            var username = GetCurrentUserName();

            try
            {
                var soNo = await _service.SaveSalesOrderAsync(request, username);
                return Ok(ApiResponse<string>.Ok(soNo, $"Sales Order '{soNo}' saved successfully."));
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "Business rule violation when saving SO: {Message}", ex.Message);
                return BadRequest(ApiResponse<string>.Fail(ex.Message));
            }
            catch (ArgumentException ex)
            {
                _logger.LogWarning(ex, "Validation error when saving SO: {Message}", ex.Message);
                return BadRequest(ApiResponse<string>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Server error while saving Sales Order");
                return StatusCode(500, ApiResponse<string>.Fail("Failed to save Sales Order. An unexpected server error occurred."));
            }
        }

        /// <summary>
        /// DELETE api/salesorder?soNo=... or DELETE api/salesorder/{**soNo}
        /// Deletes a Sales Order if not received/dispatched.
        /// </summary>
        [HttpDelete]
        [HttpDelete("{**soNo}")]
        [HttpDelete("by-no")]
        public async Task<IActionResult> DeleteSalesOrder([FromRoute] string? soNo = null, [FromQuery(Name = "soNo")] string? soNoQuery = null)
        {
            var targetSoNo = !string.IsNullOrWhiteSpace(soNoQuery) ? soNoQuery : soNo;
            if (string.IsNullOrWhiteSpace(targetSoNo))
            {
                return BadRequest(ApiResponse<bool>.Fail("Sales order number is required."));
            }

            targetSoNo = Uri.UnescapeDataString(targetSoNo).Trim();
            var username = GetCurrentUserName();

            try
            {
                var success = await _service.DeleteSalesOrderAsync(targetSoNo, username);
                if (!success)
                {
                    return BadRequest(ApiResponse<bool>.Fail($"Could not delete Sales Order '{targetSoNo}'."));
                }
                return Ok(ApiResponse<bool>.Ok(true, $"Sales Order '{targetSoNo}' deleted successfully."));
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(ApiResponse<bool>.Fail(ex.Message));
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "Business rule violation when deleting SO: {Message}", ex.Message);
                return BadRequest(ApiResponse<bool>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Server error while deleting Sales Order '{SoNo}'", targetSoNo);
                return StatusCode(500, ApiResponse<bool>.Fail("Failed to delete Sales Order. An unexpected server error occurred."));
            }
        }
    }
}
