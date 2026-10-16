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
    public class SoApprovalController : ControllerBase
    {
        private readonly ISalesOrderApprovalService _service;
        private readonly ILogger<SoApprovalController> _logger;

        public SoApprovalController(
            ISalesOrderApprovalService service,
            ILogger<SoApprovalController> logger)
        {
            _service = service;
            _logger = logger;
        }

        private string? GetCurrentUserName()
        {
            var username = User.FindFirst(ClaimTypes.Name)?.Value 
                ?? User.FindFirst("unique_name")?.Value
                ?? User.FindFirst("sub")?.Value
                ?? User.Identity?.Name;
            return string.IsNullOrWhiteSpace(username) ? null : username.Trim();
        }

        /// <summary>
        /// GET api/soapproval/lookups
        /// Returns departments, customers/parties, order numbers, and items for filter dropdowns.
        /// </summary>
        [HttpGet("lookups")]
        public async Task<IActionResult> GetLookups()
        {
            var lookups = await _service.GetLookupsAsync();
            return Ok(ApiResponse<SoApprovalLookupsDto>.Ok(lookups, "Lookups retrieved successfully."));
        }

        /// <summary>
        /// GET api/soapproval/records
        /// Returns sales order line entries matching filter parameters and view mode.
        /// </summary>
        [HttpGet("records")]
        public async Task<IActionResult> GetRecords([FromQuery] SoApprovalFilterQuery filter)
        {
            var records = await _service.GetRecordsAsync(filter);
            return Ok(ApiResponse<IEnumerable<SoApprovalRecordDto>>.Ok(records, "Sales order records retrieved successfully."));
        }

        /// <summary>
        /// GET api/soapproval/check-lock?date=...
        /// Verifies whether the specified date is locked in LOCKDATAMST.
        /// </summary>
        [HttpGet("check-lock")]
        public async Task<IActionResult> CheckLock([FromQuery] DateTime date)
        {
            var isLocked = await _service.CheckDateLockAsync(date);
            return Ok(ApiResponse<bool>.Ok(isLocked, isLocked ? "Date is locked." : "Date is open."));
        }

        /// <summary>
        /// POST api/soapproval/process
        /// Executes status action (Approve, Reject, Hold, Close, UnClose) inside an atomic SQL transaction.
        /// </summary>
        [HttpPost("process")]
        public async Task<IActionResult> ProcessAction([FromBody] SoApprovalActionRequest request)
        {
            var username = GetCurrentUserName();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<int>.Fail("Authenticated user identity is required."));
            }

            try
            {
                var count = await _service.ExecuteStatusActionAsync(request, username);
                var action = request?.ActionType ?? "Action";
                return Ok(ApiResponse<int>.Ok(count, $"{action} processed successfully for {count} item(s)."));
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "Business rule violation during SO status action: {Message}", ex.Message);
                return BadRequest(ApiResponse<int>.Fail(ex.Message));
            }
            catch (ArgumentException ex)
            {
                _logger.LogWarning(ex, "Validation error during SO status action: {Message}", ex.Message);
                return BadRequest(ApiResponse<int>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Server error executing SO status action '{Action}'", request?.ActionType);
                return StatusCode(500, ApiResponse<int>.Fail("Failed to process status action due to an internal server error."));
            }
        }
    }
}
