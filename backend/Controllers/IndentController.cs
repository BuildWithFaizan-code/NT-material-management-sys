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
    public class IndentController : ControllerBase
    {
        private readonly IIndentService _service;
        private readonly ILogger<IndentController> _logger;

        public IndentController(IIndentService service, ILogger<IndentController> logger)
        {
            _service = service ?? throw new ArgumentNullException(nameof(service));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        private (string? Username, bool IsAdmin) GetUserContext()
        {
            var username = User.FindFirst(ClaimTypes.Name)?.Value 
                ?? User.FindFirst("unique_name")?.Value
                ?? User.FindFirst("sub")?.Value
                ?? User.Identity?.Name;

            var isAdminClaim = User.FindFirst("IsAdmin")?.Value;
            var isAdmin = string.Equals(isAdminClaim, "true", StringComparison.OrdinalIgnoreCase)
                || User.IsInRole("Admin")
                || User.IsInRole("Administrator");

            return (string.IsNullOrWhiteSpace(username) ? null : username.Trim(), isAdmin);
        }

        /// <summary>
        /// GET api/indent
        /// Returns paged and filtered indent headers.
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetIndents([FromQuery] IndentFilterRequest filter)
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<IndentPagedResult<IndentHeaderDto>>.Fail("Authentication required."));
            }
            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, ApiResponse<IndentPagedResult<IndentHeaderDto>>.Fail("Administrator privileges are required to access Indent records."));
            }

            try
            {
                var result = await _service.GetIndentsAsync(filter);
                return Ok(ApiResponse<IndentPagedResult<IndentHeaderDto>>.Ok(result));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching indents");
                return StatusCode(500, ApiResponse<IndentPagedResult<IndentHeaderDto>>.Fail("Failed to retrieve indents due to an internal server error."));
            }
        }

        /// <summary>
        /// GET api/indent/lookups
        /// Returns active departments, stores, cap modes, and next sequence preview.
        /// </summary>
        [HttpGet("lookups")]
        public async Task<IActionResult> GetLookups()
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<IndentLookupsDto>.Fail("Authentication required."));
            }
            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, ApiResponse<IndentLookupsDto>.Fail("Administrator privileges are required to access Indent lookups."));
            }

            try
            {
                var lookups = await _service.GetLookupsAsync();
                return Ok(ApiResponse<IndentLookupsDto>.Ok(lookups));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching indent lookups");
                return StatusCode(500, ApiResponse<IndentLookupsDto>.Fail("Failed to retrieve indent lookups."));
            }
        }

        /// <summary>
        /// GET api/indent/cost-centers?storeCode=...
        /// Returns cost centers for the specified store location.
        /// </summary>
        [HttpGet("cost-centers")]
        public async Task<IActionResult> GetCostCenters([FromQuery] int storeCode)
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<List<IndentCostCenterLookupDto>>.Fail("Authentication required."));
            }
            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, ApiResponse<List<IndentCostCenterLookupDto>>.Fail("Administrator privileges are required."));
            }

            try
            {
                var list = await _service.GetCostCentersByStoreAsync(storeCode);
                return Ok(ApiResponse<List<IndentCostCenterLookupDto>>.Ok(list));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching cost centers for store {StoreCode}", storeCode);
                return StatusCode(500, ApiResponse<List<IndentCostCenterLookupDto>>.Fail("Failed to retrieve cost centers."));
            }
        }

        /// <summary>
        /// GET api/indent/items?search=...&page=...&pageSize=...
        /// Returns searchable item catalog for row addition.
        /// </summary>
        [HttpGet("items")]
        public async Task<IActionResult> SearchItems([FromQuery] string? search, [FromQuery] int page = 1, [FromQuery] int pageSize = 25)
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<IndentPagedResult<IndentItemLookupDto>>.Fail("Authentication required."));
            }
            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, ApiResponse<IndentPagedResult<IndentItemLookupDto>>.Fail("Administrator privileges are required."));
            }

            try
            {
                var result = await _service.SearchItemsAsync(search, page, pageSize);
                return Ok(ApiResponse<IndentPagedResult<IndentItemLookupDto>>.Ok(result));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error searching items with term {Search}", search);
                return StatusCode(500, ApiResponse<IndentPagedResult<IndentItemLookupDto>>.Fail("Failed to search item catalog."));
            }
        }

        /// <summary>
        /// GET api/indent/remarks?query=...
        /// Returns distinct remark suggestions with server-side prefix matching.
        /// </summary>
        [HttpGet("remarks")]
        public async Task<IActionResult> GetRemarkSuggestions([FromQuery] string? query)
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<List<string>>.Fail("Authentication required."));
            }
            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, ApiResponse<List<string>>.Fail("Administrator privileges are required."));
            }

            try
            {
                var suggestions = await _service.GetRemarkSuggestionsAsync(query ?? string.Empty);
                return Ok(ApiResponse<List<string>>.Ok(suggestions));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching remark suggestions");
                return StatusCode(500, ApiResponse<List<string>>.Fail("Failed to retrieve remark suggestions."));
            }
        }

        /// <summary>
        /// GET api/indent/check-lock?date=...
        /// Checks if the selected entry date is locked.
        /// </summary>
        [HttpGet("check-lock")]
        public async Task<IActionResult> CheckLock([FromQuery] DateTime date)
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<bool>.Fail("Authentication required."));
            }
            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, ApiResponse<bool>.Fail("Administrator privileges are required."));
            }

            try
            {
                var isLocked = await _service.IsDateLockedAsync(date);
                return Ok(ApiResponse<bool>.Ok(isLocked, isLocked ? "Date is locked." : "Date is open."));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error checking date lock for {Date}", date);
                return StatusCode(500, ApiResponse<bool>.Fail("Failed to check date lock status."));
            }
        }

        /// <summary>
        /// GET api/indent/by-code?code=...
        /// Returns full header and line items of an indent.
        /// </summary>
        [HttpGet("by-code")]
        public async Task<IActionResult> GetIndentByCode([FromQuery] string code)
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<IndentHeaderDto>.Fail("Authentication required."));
            }
            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, ApiResponse<IndentHeaderDto>.Fail("Administrator privileges are required."));
            }

            if (string.IsNullOrWhiteSpace(code))
            {
                return BadRequest(ApiResponse<IndentHeaderDto>.Fail("Indent Code is required."));
            }

            try
            {
                var indent = await _service.GetIndentByCodeAsync(Uri.UnescapeDataString(code).Trim());
                if (indent == null)
                {
                    return NotFound(ApiResponse<IndentHeaderDto>.Fail($"Indent '{code}' was not found."));
                }
                return Ok(ApiResponse<IndentHeaderDto>.Ok(indent));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching indent {Code}", code);
                return StatusCode(500, ApiResponse<IndentHeaderDto>.Fail("Failed to retrieve indent details."));
            }
        }

        /// <summary>
        /// POST api/indent
        /// Creates a new Indent in an atomic transaction.
        /// </summary>
        [HttpPost]
        public async Task<IActionResult> SaveIndent([FromBody] IndentSaveRequest request)
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<string>.Fail("Authenticated user identity is required."));
            }
            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, ApiResponse<string>.Fail("Administrator privileges are required to create an Indent."));
            }

            try
            {
                var indCode = await _service.SaveIndentAsync(request, username);
                return Ok(ApiResponse<string>.Ok(indCode, $"Indent {indCode} created successfully."));
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "Business rule violation saving indent by user {User}: {Message}", username, ex.Message);
                return BadRequest(ApiResponse<string>.Fail(ex.Message));
            }
            catch (ArgumentException ex)
            {
                _logger.LogWarning(ex, "Validation error saving indent by user {User}: {Message}", username, ex.Message);
                return BadRequest(ApiResponse<string>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Internal server error saving indent by user {User}", username);
                return StatusCode(500, ApiResponse<string>.Fail("Failed to save indent due to an internal server error."));
            }
        }

        /// <summary>
        /// PUT api/indent/{code}
        /// Updates an existing Indent in an atomic transaction.
        /// </summary>
        [HttpPut("{code}")]
        public async Task<IActionResult> UpdateIndent([FromRoute] string code, [FromBody] IndentSaveRequest request)
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<string>.Fail("Authenticated user identity is required."));
            }
            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, ApiResponse<string>.Fail("Administrator privileges are required to update an Indent."));
            }

            try
            {
                var indCode = await _service.UpdateIndentAsync(Uri.UnescapeDataString(code).Trim(), request, username);
                return Ok(ApiResponse<string>.Ok(indCode, $"Indent {indCode} updated successfully."));
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(ApiResponse<string>.Fail(ex.Message));
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "Business rule violation updating indent {Code} by user {User}: {Message}", code, username, ex.Message);
                return BadRequest(ApiResponse<string>.Fail(ex.Message));
            }
            catch (ArgumentException ex)
            {
                _logger.LogWarning(ex, "Validation error updating indent {Code} by user {User}: {Message}", code, username, ex.Message);
                return BadRequest(ApiResponse<string>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Internal server error updating indent {Code} by user {User}", code, username);
                return StatusCode(500, ApiResponse<string>.Fail("Failed to update indent due to an internal server error."));
            }
        }

        /// <summary>
        /// DELETE api/indent/{code}
        /// Deletes an Indent and reverses linked requisitions in an atomic transaction.
        /// </summary>
        [HttpDelete("{code}")]
        public async Task<IActionResult> DeleteIndent([FromRoute] string code)
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<bool>.Fail("Authenticated user identity is required."));
            }
            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, ApiResponse<bool>.Fail("Administrator privileges are required to delete an Indent."));
            }

            try
            {
                var deleted = await _service.DeleteIndentAsync(Uri.UnescapeDataString(code).Trim(), username);
                if (!deleted)
                {
                    return NotFound(ApiResponse<bool>.Fail($"Indent '{code}' was not found."));
                }
                return Ok(ApiResponse<bool>.Ok(true, $"Indent {code} deleted successfully."));
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "Business rule violation deleting indent {Code} by user {User}: {Message}", code, username, ex.Message);
                return BadRequest(ApiResponse<bool>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Internal server error deleting indent {Code} by user {User}", code, username);
                return StatusCode(500, ApiResponse<bool>.Fail("Failed to delete indent due to an internal server error."));
            }
        }
    }
}
