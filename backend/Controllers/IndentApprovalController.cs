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
    public class IndentApprovalController : ControllerBase
    {
        private readonly IIndentApprovalService _service;
        private readonly ILogger<IndentApprovalController> _logger;

        public IndentApprovalController(
            IIndentApprovalService service,
            ILogger<IndentApprovalController> logger)
        {
            _service = service ?? throw new ArgumentNullException(nameof(service));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        private string GetCurrentUserName()
        {
            var username = User.FindFirst(ClaimTypes.Name)?.Value 
                ?? User.Identity?.Name;
            return string.IsNullOrWhiteSpace(username) ? "ADMIN" : username.Trim();
        }

        /// <summary>
        /// GET /api/indentapproval/lookups
        /// Returns filter dropdown lists for Indent Nos, Departments, and Pending Items.
        /// </summary>
        [HttpGet("lookups")]
        public async Task<IActionResult> GetLookups()
        {
            var lookups = await _service.GetLookupsAsync();
            return Ok(ApiResponse<IndentApprovalLookupsDto>.Ok(lookups, "Indent approval lookups retrieved."));
        }

        /// <summary>
        /// GET /api/indentapproval/records
        /// Returns indent items matching filter criteria.
        /// </summary>
        [HttpGet("records")]
        public async Task<IActionResult> GetRecords(
            [FromQuery] DateTime? asOnDate,
            [FromQuery] DateTime? fromDate,
            [FromQuery] DateTime? toDate,
            [FromQuery] string? statusFilter,
            [FromQuery] string? indCode,
            [FromQuery] int? deptCode,
            [FromQuery] string? itemCode)
        {
            var records = await _service.GetRecordsAsync(
                asOnDate, fromDate, toDate, statusFilter, indCode, deptCode, itemCode);
            return Ok(ApiResponse<IEnumerable<IndentApprovalRecordDto>>.Ok(records, "Indent approval records retrieved."));
        }

        /// <summary>
        /// GET /api/indentapproval/check-lock?date=...
        /// Verifies whether the specified date is locked in LOCKDATAMST.
        /// </summary>
        [HttpGet("check-lock")]
        public async Task<IActionResult> CheckLock([FromQuery] DateTime date)
        {
            var isLocked = await _service.CheckDateLockAsync(date);
            return Ok(ApiResponse<bool>.Ok(isLocked, isLocked ? "Date is locked." : "Date is open."));
        }

        /// <summary>
        /// POST /api/indentapproval/process
        /// Atomically updates selected items to Approved, Rejected, Hold, or Reset inside a single SQL transaction.
        /// </summary>
        [HttpPost("process")]
        public async Task<IActionResult> ProcessBatch([FromBody] IndentApprovalActionRequest request)
        {
            if (request == null || request.Items == null || request.Items.Count == 0)
            {
                return BadRequest(ApiResponse<string>.Fail("No indent items provided for approval processing."));
            }

            try
            {
                var username = GetCurrentUserName();
                var result = await _service.ProcessApprovalBatchAsync(request, username);
                if (!result.Success)
                {
                    return BadRequest(ApiResponse<IndentApprovalActionResult>.Fail(result.Message));
                }

                return Ok(ApiResponse<IndentApprovalActionResult>.Ok(result, result.Message));
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "Validation failure during indent approval: {Message}", ex.Message);
                return BadRequest(ApiResponse<string>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error processing indent approvals");
                return StatusCode(500, ApiResponse<string>.Fail("An error occurred while processing indent approvals."));
            }
        }
    }
}
