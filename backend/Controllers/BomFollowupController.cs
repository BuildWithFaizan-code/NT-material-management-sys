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
    [AllowAnonymous]
    public class BomFollowupController : ControllerBase
    {
        private readonly IBomFollowupService _service;
        private readonly ILogger<BomFollowupController> _logger;

        public BomFollowupController(IBomFollowupService service, ILogger<BomFollowupController> logger)
        {
            _service = service;
            _logger = logger;
        }

        private string GetCurrentUserName()
        {
            return User.FindFirst(ClaimTypes.Name)?.Value 
                ?? User.Identity?.Name 
                ?? "ADMIN";
        }

        /// <summary>
        /// GET api/bomfollowup/departments
        /// Returns departments from LABOURMST for filter dropdown.
        /// </summary>
        [HttpGet("departments")]
        public async Task<IActionResult> GetDepartments()
        {
            var depts = await _service.GetDepartmentsAsync();
            return Ok(ApiResponse<IEnumerable<BomFollowupDepartmentDto>>.Ok(depts));
        }

        /// <summary>
        /// GET api/bomfollowup/divisions
        /// Returns divisions from KHATAMST for filter dropdown.
        /// </summary>
        [HttpGet("divisions")]
        public async Task<IActionResult> GetDivisions()
        {
            var divisions = await _service.GetDivisionsAsync();
            return Ok(ApiResponse<IEnumerable<BomFollowupDivisionDto>>.Ok(divisions));
        }

        /// <summary>
        /// GET api/bomfollowup/order-types
        /// Returns distinct BOM types for filter dropdown.
        /// </summary>
        [HttpGet("order-types")]
        public async Task<IActionResult> GetOrderTypes()
        {
            var types = await _service.GetOrderTypesAsync();
            return Ok(ApiResponse<IEnumerable<BomFollowupOrderTypeDto>>.Ok(types));
        }

        /// <summary>
        /// GET api/bomfollowup/records
        /// Returns active OPEN BOM records matching filter parameters.
        /// </summary>
        [HttpGet("records")]
        public async Task<IActionResult> GetRecords(
            [FromQuery] DateTime? asOnDate,
            [FromQuery] int? departmentCode,
            [FromQuery] int? divisionCode,
            [FromQuery] string? orderType)
        {
            var records = await _service.GetOpenRecordsAsync(asOnDate, departmentCode, divisionCode, orderType);
            return Ok(ApiResponse<IEnumerable<BomFollowupRecordDto>>.Ok(records, "BOM Followup records fetched successfully."));
        }

        /// <summary>
        /// GET api/bomfollowup/check-lock?date=...
        /// Verifies whether the specified date is locked in LOCKDATAMST.
        /// </summary>
        [HttpGet("check-lock")]
        public async Task<IActionResult> CheckLock([FromQuery] DateTime date)
        {
            var isLocked = await _service.CheckDateLockAsync(date);
            return Ok(ApiResponse<bool>.Ok(isLocked, isLocked ? "Date is locked." : "Date is open."));
        }

        /// <summary>
        /// POST api/bomfollowup/close
        /// Batch closes selected BOMs inside a single SQL transaction and writes DAYBOOK audit logs.
        /// </summary>
        [HttpPost("close")]
        public async Task<IActionResult> CloseBatch([FromBody] BomFollowupCloseRequest request)
        {
            if (request == null || request.BomIds == null || request.BomIds.Count == 0)
            {
                return BadRequest(ApiResponse<string>.Fail("No BOM records provided for closing."));
            }

            try
            {
                var username = GetCurrentUserName();
                var result = await _service.CloseBatchAsync(request.BomIds, request.AsOnDate, username, "NEWTECHINFOSOL");
                if (!result.Success)
                {
                    return BadRequest(ApiResponse<BomFollowupCloseResult>.Fail(result.Message));
                }

                return Ok(ApiResponse<BomFollowupCloseResult>.Ok(result, result.Message));
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "Business rule violation when closing BOMs: {Message}", ex.Message);
                return BadRequest(ApiResponse<string>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Server error while batch closing BOMs");
                return StatusCode(500, ApiResponse<string>.Fail("Failed to close BOM records. Server error."));
            }
        }
    }
}
