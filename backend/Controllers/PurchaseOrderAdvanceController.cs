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
    [Authorize]
    [Route("api/[controller]")]
    [Route("api/po-advance")]
    public class PurchaseOrderAdvanceController : ControllerBase
    {
        private readonly IPurchaseOrderAdvanceService _service;
        private readonly ILogger<PurchaseOrderAdvanceController> _logger;

        public PurchaseOrderAdvanceController(
            IPurchaseOrderAdvanceService service,
            ILogger<PurchaseOrderAdvanceController> logger)
        {
            _service = service;
            _logger = logger;
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
        /// GET api/purchaseorderadvance/parties
        /// Returns suppliers with approved purchase orders.
        /// </summary>
        [HttpGet("parties")]
        public async Task<IActionResult> GetApprovedPoParties()
        {
            var parties = await _service.GetApprovedPoPartiesAsync();
            return Ok(ApiResponse<IEnumerable<PoAdvancePartyLookupDto>>.Ok(parties, "Approved PO suppliers retrieved successfully."));
        }

        /// <summary>
        /// GET api/purchaseorderadvance/pos?partyCode=...
        /// Returns un-received, approved PO numbers for the specified party.
        /// </summary>
        [HttpGet("pos")]
        public async Task<IActionResult> GetApprovedPosForParty([FromQuery] int partyCode)
        {
            var pos = await _service.GetApprovedPosForPartyAsync(partyCode);
            return Ok(ApiResponse<IEnumerable<string>>.Ok(pos, "Approved PO numbers retrieved successfully."));
        }

        /// <summary>
        /// GET api/purchaseorderadvance/po-details?poNo=...&appDate=...
        /// Returns PO date, NETAMT, total prior advances, and remaining balance.
        /// </summary>
        [HttpGet("po-details")]
        public async Task<IActionResult> GetPoHeaderDetails([FromQuery] string poNo, [FromQuery] DateTime? appDate)
        {
            var date = appDate ?? DateTime.Today;
            var details = await _service.GetPoHeaderDetailsAsync(poNo, date);
            if (details == null)
            {
                return NotFound(ApiResponse<PoAdvanceHeaderDetailsDto>.Fail($"Purchase order '{poNo}' was not found."));
            }
            return Ok(ApiResponse<PoAdvanceHeaderDetailsDto>.Ok(details, "PO details retrieved successfully."));
        }

        /// <summary>
        /// GET api/purchaseorderadvance/history?poNo=...
        /// Returns advance payments history for the specified PO.
        /// </summary>
        [HttpGet("history")]
        public async Task<IActionResult> GetPoAdvanceHistory([FromQuery] string poNo)
        {
            var history = await _service.GetPoAdvanceHistoryAsync(poNo);
            return Ok(ApiResponse<IEnumerable<PoAdvanceHistoryRecordDto>>.Ok(history, "PO advance history retrieved successfully."));
        }

        /// <summary>
        /// GET api/purchaseorderadvance/all?search=...&limit=...
        /// Returns all advance payment records across all suppliers and POs for the master Show Record grid.
        /// </summary>
        [HttpGet("all")]
        public async Task<IActionResult> GetAllAdvances([FromQuery] string? search, [FromQuery] int limit = 500)
        {
            var list = await _service.GetAllAdvancesAsync(search, limit);
            return Ok(ApiResponse<IEnumerable<PoAdvanceHistoryRecordDto>>.Ok(list, "Master PO advance records retrieved successfully."));
        }

        /// <summary>
        /// GET api/purchaseorderadvance/party-advances?partyCode=...
        /// Returns summary of all advances given to the supplier across all POs.
        /// </summary>
        [HttpGet("party-advances")]
        public async Task<IActionResult> GetPartyAdvanceSummaries([FromQuery] int partyCode)
        {
            var list = await _service.GetPartyAdvanceSummariesAsync(partyCode);
            return Ok(ApiResponse<IEnumerable<PoAdvancePartySummaryDto>>.Ok(list, "Party advance summaries retrieved successfully."));
        }

        /// <summary>
        /// GET api/purchaseorderadvance/check-lock?date=...
        /// Verifies whether the transaction date is locked in LOCKDATAMST.
        /// </summary>
        [HttpGet("check-lock")]
        public async Task<IActionResult> CheckLock([FromQuery] DateTime date)
        {
            var isLocked = await _service.CheckDateLockAsync(date);
            return Ok(ApiResponse<bool>.Ok(isLocked, isLocked ? "Date is locked." : "Date is open."));
        }

        /// <summary>
        /// POST api/purchaseorderadvance
        /// Inserts a new PO Advance record into POADVANCEMST inside an atomic transaction.
        /// </summary>
        [HttpPost]
        public async Task<IActionResult> CreateAdvance([FromBody] PoAdvanceCreateRequest request)
        {
            var username = GetCurrentUserName();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<int>.Fail("Authenticated user identity is required."));
            }

            try
            {
                var newId = await _service.CreateAdvanceAsync(request, username);
                return Ok(ApiResponse<int>.Ok(newId, $"Advance payment of ₹{request.AppAmt:N2} posted successfully (ID #{newId})."));
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "Business rule violation creating PO advance: {Message}", ex.Message);
                return BadRequest(ApiResponse<int>.Fail(ex.Message));
            }
            catch (ArgumentException ex)
            {
                _logger.LogWarning(ex, "Validation error creating PO advance: {Message}", ex.Message);
                return BadRequest(ApiResponse<int>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Server error creating PO advance for PO '{PoNo}'", request?.PoNo);
                return StatusCode(500, ApiResponse<int>.Fail("Failed to record advance payment due to an internal server error."));
            }
        }

        /// <summary>
        /// DELETE api/purchaseorderadvance/{poId}
        /// Deletes/voids an advance record by its ID.
        /// </summary>
        [HttpDelete("{poId}")]
        public async Task<IActionResult> DeleteAdvance([FromRoute] int poId)
        {
            var username = GetCurrentUserName();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<bool>.Fail("Authenticated user identity is required."));
            }

            try
            {
                var success = await _service.DeleteAdvanceAsync(poId);
                if (!success)
                {
                    return NotFound(ApiResponse<bool>.Fail($"Advance record #{poId} was not found."));
                }
                return Ok(ApiResponse<bool>.Ok(true, $"Advance record #{poId} deleted successfully."));
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "Business rule violation deleting PO advance: {Message}", ex.Message);
                return BadRequest(ApiResponse<bool>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Server error deleting PO advance #{PoId}", poId);
                return StatusCode(500, ApiResponse<bool>.Fail("Failed to delete advance payment due to an internal server error."));
            }
        }
    }
}
