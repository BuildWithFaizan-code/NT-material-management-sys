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
    public class StockTransferController : ControllerBase
    {
        private readonly IStockTransferService _service;
        private readonly ILogger<StockTransferController> _logger;

        public StockTransferController(IStockTransferService service, ILogger<StockTransferController> logger)
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
        public async Task<ActionResult<ApiResponse<StockTransferLookupsDto>>> GetLookups([FromQuery] int? fromStoreId)
        {
            try
            {
                var data = await _service.GetLookupsAsync(fromStoreId);
                return Ok(ApiResponse<StockTransferLookupsDto>.Ok(data));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to load Stock Transfer lookups.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<StockTransferLookupsDto>.Fail("An error occurred while loading lookups."));
            }
        }

        [HttpGet("preview-code")]
        public async Task<ActionResult<ApiResponse<string>>> GetPreviewCode(
            [FromQuery] DateTime? date, [FromQuery] string? issueMode)
        {
            try
            {
                var targetDate = date ?? DateTime.Today;
                var mode = string.IsNullOrWhiteSpace(issueMode) ? "Stock Transfer" : issueMode;
                var code = await _service.GetNextIssueCodePreviewAsync(targetDate, mode);
                return Ok(ApiResponse<string>.Ok(code));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to generate preview code.");
                return StatusCode(StatusCodes.Status500InternalServerError,
                    ApiResponse<string>.Fail("An error occurred while generating code."));
            }
        }

        [HttpGet("to-stores")]
        public async Task<ActionResult<ApiResponse<List<StockTransferLookupItemDto>>>> GetToStores([FromQuery] int fromStoreId)
        {
            try
            {
                var data = await _service.GetToStoresAsync(fromStoreId);
                return Ok(ApiResponse<List<StockTransferLookupItemDto>>.Ok(data));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to load To-Stores for fromStoreId {StoreId}.", fromStoreId);
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<List<StockTransferLookupItemDto>>.Fail("An error occurred while loading stores."));
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
                _logger.LogError(ex, "Failed to load stock catalog.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<StockCatalogPagedResultDto>.Fail("An error occurred while searching stock items."));
            }
        }

        [HttpGet("pending-requisitions")]
        public async Task<ActionResult<ApiResponse<List<PendingRequisitionItemDto>>>> GetPendingRequisitions([FromQuery] string? search)
        {
            try
            {
                var data = await _service.GetPendingRequisitionsAsync(search);
                return Ok(ApiResponse<List<PendingRequisitionItemDto>>.Ok(data));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to load pending requisitions.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<List<PendingRequisitionItemDto>>.Fail("An error occurred while fetching pending requisitions."));
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
                _logger.LogError(ex, "Failed to verify stock availability.");
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
                _logger.LogError(ex, "Failed to check date lock status.");
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
                _logger.LogError(ex, "Failed to fetch remark suggestions.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<List<string>>.Fail("An error occurred while fetching suggestions."));
            }
        }

        [HttpGet("records")]
        public async Task<ActionResult<ApiResponse<StockTransferPagedListDto>>> GetTransfers(
            [FromQuery] DateTime? fromDate,
            [FromQuery] DateTime? toDate,
            [FromQuery] string? search,
            [FromQuery] string? issueMode,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 25)
        {
            try
            {
                var data = await _service.GetTransfersAsync(fromDate, toDate, search, issueMode, page, pageSize);
                return Ok(ApiResponse<StockTransferPagedListDto>.Ok(data));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to fetch stock transfers.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<StockTransferPagedListDto>.Fail("An error occurred while loading stock transfers."));
            }
        }

        [HttpGet("by-code")]
        public async Task<ActionResult<ApiResponse<StockTransferDetailDto>>> GetTransferByQueryCode([FromQuery] string code)
        {
            return await GetTransferByCode(code);
        }

        [HttpGet("{code}")]
        public async Task<ActionResult<ApiResponse<StockTransferDetailDto>>> GetTransferByCode(string code)
        {
            try
            {
                var data = await _service.GetTransferByCodeAsync(code);
                if (data == null)
                    return NotFound(ApiResponse<StockTransferDetailDto>.Fail($"Stock transfer {code} not found."));

                return Ok(ApiResponse<StockTransferDetailDto>.Ok(data));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to fetch stock transfer details for {Code}.", code);
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<StockTransferDetailDto>.Fail("An error occurred while loading transfer details."));
            }
        }

        [HttpPost]
        public async Task<ActionResult<ApiResponse<StockTransferSaveResultDto>>> CreateTransfer([FromBody] StockTransferCreateRequestDto request)
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<StockTransferSaveResultDto>.Fail("Authentication required."));
            }

            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, 
                    ApiResponse<StockTransferSaveResultDto>.Fail("Forbidden: Admin privileges required to create stock transfer."));
            }

            try
            {
                var result = await _service.CreateTransferAsync(request, username);
                return Ok(ApiResponse<StockTransferSaveResultDto>.Ok(result, result.Message));
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiResponse<StockTransferSaveResultDto>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error creating stock transfer.");
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<StockTransferSaveResultDto>.Fail(ex.Message));
            }
        }

        [HttpPut("by-code")]
        public async Task<ActionResult<ApiResponse<StockTransferSaveResultDto>>> UpdateTransfer(
            [FromQuery] string code, [FromBody] StockTransferCreateRequestDto request)
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<StockTransferSaveResultDto>.Fail("Authentication required."));
            }

            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, 
                    ApiResponse<StockTransferSaveResultDto>.Fail("Forbidden: Admin privileges required to update stock transfer."));
            }

            try
            {
                var result = await _service.UpdateTransferAsync(code, request, username);
                return Ok(ApiResponse<StockTransferSaveResultDto>.Ok(result, result.Message));
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(ApiResponse<StockTransferSaveResultDto>.Fail(ex.Message));
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiResponse<StockTransferSaveResultDto>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error updating stock transfer {Code}.", code);
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<StockTransferSaveResultDto>.Fail(ex.Message));
            }
        }

        [HttpDelete("by-code")]
        public async Task<ActionResult<ApiResponse<StockTransferSaveResultDto>>> DeleteTransfer([FromQuery] string code)
        {
            var (username, isAdmin) = GetUserContext();
            if (string.IsNullOrWhiteSpace(username))
            {
                return Unauthorized(ApiResponse<StockTransferSaveResultDto>.Fail("Authentication required."));
            }

            if (!isAdmin)
            {
                return StatusCode(StatusCodes.Status403Forbidden, 
                    ApiResponse<StockTransferSaveResultDto>.Fail("Forbidden: Admin privileges required to delete stock transfer."));
            }

            try
            {
                var result = await _service.DeleteTransferAsync(code, username);
                return Ok(ApiResponse<StockTransferSaveResultDto>.Ok(result, result.Message));
            }
            catch (KeyNotFoundException ex)
            {
                return NotFound(ApiResponse<StockTransferSaveResultDto>.Fail(ex.Message));
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ApiResponse<StockTransferSaveResultDto>.Fail(ex.Message));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error deleting stock transfer {Code}.", code);
                return StatusCode(StatusCodes.Status500InternalServerError, 
                    ApiResponse<StockTransferSaveResultDto>.Fail(ex.Message));
            }
        }
    }
}
