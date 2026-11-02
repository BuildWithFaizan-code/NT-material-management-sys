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
    public class MaterialReturnController : ControllerBase
    {
        private readonly IMaterialReturnService _service;
        private readonly ILogger<MaterialReturnController> _logger;

        public MaterialReturnController(IMaterialReturnService service, ILogger<MaterialReturnController> logger)
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
        public async Task<ActionResult<ApiResponse<MaterialReturnLookupsDto>>> GetLookups()
        {
            try
            {
                var data = await _service.GetLookupsAsync();
                return Ok(ApiResponse<MaterialReturnLookupsDto>.Ok(data));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to load Material Return lookups.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<MaterialReturnLookupsDto>.Fail("An error occurred while loading lookups."));
            }
        }

        [HttpGet("preview-code")]
        public async Task<ActionResult<ApiResponse<string>>> GetPreviewCode(
            [FromQuery] DateTime? date, [FromQuery] string? retMode, [FromQuery] string? entityName)
        {
            try
            {
                var targetDate = date ?? DateTime.Today;
                var mode = string.IsNullOrWhiteSpace(retMode) ? "From Department" : retMode.Trim();
                var entity = entityName ?? string.Empty;

                var code = await _service.GetNextPreviewCodeAsync(targetDate, mode, entity);
                return Ok(ApiResponse<string>.Ok(code));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to generate Material Return preview code.");
                return StatusCode(StatusCodes.Status500InternalServerError,
                    ApiResponse<string>.Fail("An error occurred while generating return code."));
            }
        }

        [HttpGet("stock-catalog")]
        public async Task<ActionResult<ApiResponse<MaterialReturnStockCatalogPagedResultDto>>> GetStockCatalog(
            [FromQuery] DateTime date,
            [FromQuery] int deptCode,
            [FromQuery] int storeId,
            [FromQuery] int divId,
            [FromQuery] string? search,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 50)
        {
            try
            {
                var data = await _service.GetStockCatalogAsync(date, deptCode, storeId, divId, search, page, pageSize);
                return Ok(ApiResponse<MaterialReturnStockCatalogPagedResultDto>.Ok(data));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to load stock catalog for Material Return.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<MaterialReturnStockCatalogPagedResultDto>.Fail("An error occurred while searching catalog items."));
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
            [FromQuery] int deptCode,
            [FromQuery] int storeId,
            [FromQuery] int divId,
            [FromQuery] int uom)
        {
            try
            {
                var data = await _service.CheckStockAvailabilityAsync(
                    date, currentDocNo ?? string.Empty, itemCode, mrgNo ?? string.Empty, grade ?? string.Empty, shade ?? string.Empty,
                    deptCode, storeId, divId, uom);
                return Ok(ApiResponse<double>.Ok(data));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to verify stock availability for Material Return.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<double>.Fail("An error occurred while checking stock."));
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
                _logger.LogError(ex, "Failed to check date lock status for Material Return.");
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
                _logger.LogError(ex, "Failed to fetch remark suggestions for Material Return.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<List<string>>.Fail("An error occurred while fetching suggestions."));
            }
        }

        [HttpGet("records")]
        public async Task<ActionResult<ApiResponse<MaterialReturnPagedListDto>>> GetReturns(
            [FromQuery] DateTime? fromDate,
            [FromQuery] DateTime? toDate,
            [FromQuery] string? search,
            [FromQuery] string? retMode,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 25)
        {
            try
            {
                var data = await _service.GetReturnsAsync(fromDate, toDate, search, retMode, page, pageSize);
                return Ok(ApiResponse<MaterialReturnPagedListDto>.Ok(data));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to fetch returns in Material Return.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<MaterialReturnPagedListDto>.Fail("An error occurred while loading returns."));
            }
        }

        [HttpGet("by-code")]
        public async Task<ActionResult<ApiResponse<MaterialReturnDetailDto>>> GetReturnByCode([FromQuery] string code)
        {
            try
            {
                var data = await _service.GetReturnByCodeAsync(code);
                if (data == null)
                    return NotFound(ApiResponse<MaterialReturnDetailDto>.Fail($"Material return {code} not found."));

                return Ok(ApiResponse<MaterialReturnDetailDto>.Ok(data));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to fetch return details for {Code}.", code);
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<MaterialReturnDetailDto>.Fail("An error occurred while loading return details."));
            }
        }

        [HttpPost]
        public async Task<ActionResult<ApiResponse<MaterialReturnSaveResultDto>>> CreateReturn([FromBody] MaterialReturnCreateRequestDto request)
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<MaterialReturnSaveResultDto>.Fail("Authentication required."));
            }

            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, 
                    ApiResponse<MaterialReturnSaveResultDto>.Fail("Forbidden: Admin privileges required for Material Return."));
            }

            try
            {
                var result = await _service.CreateReturnAsync(request, username);
                return Ok(ApiResponse<MaterialReturnSaveResultDto>.Ok(result, result.Message));
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiResponse<MaterialReturnSaveResultDto>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error creating Material Return transaction.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<MaterialReturnSaveResultDto>.Fail(ex.Message));
            }
        }

        [HttpPut("by-code")]
        public async Task<ActionResult<ApiResponse<MaterialReturnSaveResultDto>>> UpdateReturn(
            [FromQuery] string code, [FromBody] MaterialReturnCreateRequestDto request)
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<MaterialReturnSaveResultDto>.Fail("Authentication required."));
            }

            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, 
                    ApiResponse<MaterialReturnSaveResultDto>.Fail("Forbidden: Admin privileges required for Material Return."));
            }

            try
            {
                var result = await _service.UpdateReturnAsync(code, request, username);
                return Ok(ApiResponse<MaterialReturnSaveResultDto>.Ok(result, result.Message));
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(ApiResponse<MaterialReturnSaveResultDto>.Fail(ex.Message));
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiResponse<MaterialReturnSaveResultDto>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error updating Material Return {Code}.", code);
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<MaterialReturnSaveResultDto>.Fail(ex.Message));
            }
        }

        [HttpDelete("by-code")]
        public async Task<ActionResult<ApiResponse<MaterialReturnSaveResultDto>>> DeleteReturn([FromQuery] string code)
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<MaterialReturnSaveResultDto>.Fail("Authentication required."));
            }

            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, 
                    ApiResponse<MaterialReturnSaveResultDto>.Fail("Forbidden: Admin privileges required for Material Return."));
            }

            try
            {
                var result = await _service.DeleteReturnAsync(code, username);
                return Ok(ApiResponse<MaterialReturnSaveResultDto>.Ok(result, result.Message));
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(ApiResponse<MaterialReturnSaveResultDto>.Fail(ex.Message));
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiResponse<MaterialReturnSaveResultDto>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error deleting Material Return {Code}.", code);
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<MaterialReturnSaveResultDto>.Fail(ex.Message));
            }
        }
    }
}
