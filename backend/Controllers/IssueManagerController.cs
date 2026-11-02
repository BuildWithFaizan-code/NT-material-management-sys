using System;
using System.Collections.Generic;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class IssueManagerController : ControllerBase
    {
        private readonly IIssueManagerService _service;
        private readonly ILogger<IssueManagerController> _logger;

        public IssueManagerController(IIssueManagerService service, ILogger<IssueManagerController> logger)
        {
            _service = service ?? throw new ArgumentNullException(nameof(service));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        private (string? Username, bool IsAdmin) GetUserContext()
        {
            var username = User.FindFirst(ClaimTypes.Name)?.Value 
                ?? User.FindFirst("name")?.Value 
                ?? User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

            var isAdminClaim = User.FindFirst("isAdmin")?.Value;
            var isAdmin = string.Equals(isAdminClaim, "true", StringComparison.OrdinalIgnoreCase) 
                || User.IsInRole("Admin");

            return (username, isAdmin);
        }

        [HttpGet("lookups")]
        public async Task<ActionResult<ApiResponse<IssueManagerLookupsDto>>> GetLookups()
        {
            try
            {
                var data = await _service.GetLookupsAsync();
                return Ok(ApiResponse<IssueManagerLookupsDto>.Ok(data));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to load Issue Manager lookups.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<IssueManagerLookupsDto>.Fail("An error occurred while loading lookups."));
            }
        }

        [HttpGet("preview-code")]
        public async Task<ActionResult<ApiResponse<string>>> GetPreviewCode(
            [FromQuery] DateTime? date, [FromQuery] string? issueMode, [FromQuery] string? fromDeptName)
        {
            try
            {
                var targetDate = date ?? DateTime.Today;
                var mode = string.IsNullOrWhiteSpace(issueMode) ? "To Department" : issueMode.Trim();
                var dept = fromDeptName ?? string.Empty;

                var code = await _service.GetNextPreviewCodeAsync(targetDate, mode, dept);
                return Ok(ApiResponse<string>.Ok(code));
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiResponse<string>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to generate Issue Manager preview code.");
                return StatusCode(StatusCodes.Status500InternalServerError,
                    ApiResponse<string>.Fail("An error occurred while generating code."));
            }
        }

        [HttpGet("stock-catalog")]
        public async Task<ActionResult<ApiResponse<StockCatalogPagedResultDto>>> GetStockCatalog(
            [FromQuery] DateTime date,
            [FromQuery] int sourceDept,
            [FromQuery] int sourceStore,
            [FromQuery] int sourceDiv,
            [FromQuery] string? search,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 50)
        {
            try
            {
                var data = await _service.GetStockCatalogAsync(date, sourceDept, sourceStore, sourceDiv, search, page, pageSize);
                return Ok(ApiResponse<StockCatalogPagedResultDto>.Ok(data));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to load stock catalog for Issue Manager.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<StockCatalogPagedResultDto>.Fail("An error occurred while searching stock items."));
            }
        }

        [HttpGet("check-stock")]
        public async Task<ActionResult<ApiResponse<double>>> CheckStock(
            [FromQuery] DateTime date,
            [FromQuery] string? currentDocNo,
            [FromQuery] string itemCode,
            [FromQuery] string? mrgNo,
            [FromQuery] string? grade,
            [FromQuery] string? shade,
            [FromQuery] int sourceDept,
            [FromQuery] int sourceStore,
            [FromQuery] int sourceDiv,
            [FromQuery] int uom)
        {
            try
            {
                var data = await _service.CheckStockAvailabilityAsync(
                    date, currentDocNo ?? string.Empty, itemCode, mrgNo ?? string.Empty, grade ?? string.Empty, shade ?? string.Empty,
                    sourceDept, sourceStore, sourceDiv, uom);
                return Ok(ApiResponse<double>.Ok(data));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to verify stock availability for Issue Manager.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<double>.Fail("An error occurred while verifying item stock."));
            }
        }

        [HttpGet("is-date-locked")]
        public async Task<ActionResult<ApiResponse<bool>>> IsDateLocked([FromQuery] DateTime date)
        {
            try
            {
                var isLocked = await _service.IsDateLockedAsync(date);
                return Ok(ApiResponse<bool>.Ok(isLocked));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to check date lock status for Issue Manager.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<bool>.Fail("An error occurred while verifying date lock."));
            }
        }

        [HttpGet("remark-suggestions")]
        public async Task<ActionResult<ApiResponse<List<string>>>> GetRemarkSuggestions([FromQuery] string? query)
        {
            try
            {
                var data = await _service.GetRemarkSuggestionsAsync(query ?? string.Empty);
                return Ok(ApiResponse<List<string>>.Ok(data));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to fetch remark suggestions for Issue Manager.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<List<string>>.Fail("An error occurred while fetching suggestions."));
            }
        }

        [HttpGet("records")]
        public async Task<ActionResult<ApiResponse<IssueManagerPagedListDto>>> GetIssues(
            [FromQuery] DateTime? fromDate,
            [FromQuery] DateTime? toDate,
            [FromQuery] string? search,
            [FromQuery] string? issueMode,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 25)
        {
            try
            {
                var data = await _service.GetIssuesAsync(fromDate, toDate, search, issueMode, page, pageSize);
                return Ok(ApiResponse<IssueManagerPagedListDto>.Ok(data));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to fetch issues in Issue Manager.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<IssueManagerPagedListDto>.Fail("An error occurred while loading issues."));
            }
        }

        [HttpGet("by-code")]
        public async Task<ActionResult<ApiResponse<IssueManagerDetailDto>>> GetIssueByCode([FromQuery] string code)
        {
            try
            {
                var data = await _service.GetIssueByCodeAsync(code);
                if (data == null)
                    return NotFound(ApiResponse<IssueManagerDetailDto>.Fail($"Issue {code} not found."));

                return Ok(ApiResponse<IssueManagerDetailDto>.Ok(data));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to fetch issue details for {Code}.", code);
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<IssueManagerDetailDto>.Fail("An error occurred while loading issue details."));
            }
        }

        [HttpPost]
        public async Task<ActionResult<ApiResponse<IssueManagerSaveResultDto>>> CreateIssue([FromBody] IssueManagerCreateRequestDto request)
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<IssueManagerSaveResultDto>.Fail("Authentication required."));
            }

            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, 
                    ApiResponse<IssueManagerSaveResultDto>.Fail("Forbidden: Admin privileges required for Issue Manager."));
            }

            try
            {
                var result = await _service.CreateIssueAsync(request, username);
                return Ok(ApiResponse<IssueManagerSaveResultDto>.Ok(result, result.Message));
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiResponse<IssueManagerSaveResultDto>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error creating Issue Manager transaction.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<IssueManagerSaveResultDto>.Fail(ex.Message));
            }
        }

        [HttpPut("by-code")]
        public async Task<ActionResult<ApiResponse<IssueManagerSaveResultDto>>> UpdateIssue(
            [FromQuery] string code, [FromBody] IssueManagerCreateRequestDto request)
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<IssueManagerSaveResultDto>.Fail("Authentication required."));
            }

            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, 
                    ApiResponse<IssueManagerSaveResultDto>.Fail("Forbidden: Admin privileges required for Issue Manager."));
            }

            try
            {
                var result = await _service.UpdateIssueAsync(code, request, username);
                return Ok(ApiResponse<IssueManagerSaveResultDto>.Ok(result, result.Message));
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(ApiResponse<IssueManagerSaveResultDto>.Fail(ex.Message));
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiResponse<IssueManagerSaveResultDto>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error updating Issue {Code}.", code);
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<IssueManagerSaveResultDto>.Fail(ex.Message));
            }
        }

        [HttpDelete("by-code")]
        public async Task<ActionResult<ApiResponse<IssueManagerSaveResultDto>>> DeleteIssue([FromQuery] string code)
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<IssueManagerSaveResultDto>.Fail("Authentication required."));
            }

            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, 
                    ApiResponse<IssueManagerSaveResultDto>.Fail("Forbidden: Admin privileges required for Issue Manager."));
            }

            try
            {
                var result = await _service.DeleteIssueAsync(code, username);
                return Ok(ApiResponse<IssueManagerSaveResultDto>.Ok(result, result.Message));
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(ApiResponse<IssueManagerSaveResultDto>.Fail(ex.Message));
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiResponse<IssueManagerSaveResultDto>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error deleting Issue {Code}.", code);
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<IssueManagerSaveResultDto>.Fail(ex.Message));
            }
        }
    }
}
