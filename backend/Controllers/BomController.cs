using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [AllowAnonymous] // Seamless enterprise integration with development bypass
    public class BomController : ControllerBase
    {
        private readonly IBomService _service;

        public BomController(IBomService service)
        {
            _service = service;
        }

        /// <summary>
        /// GET api/bom/next-id?mode=JOB
        /// Returns next sequential BOM ID formatted as BMCJ/000001/27 or BMCC/000001/27.
        /// </summary>
        [HttpGet("next-id")]
        public async Task<IActionResult> GetNextId([FromQuery] string? mode)
        {
            var nextId = await _service.GetNextBomIdAsync(mode ?? "JOB");
            return Ok(ApiResponse<string>.Ok(nextId, "Next BOM ID generated."));
        }

        /// <summary>
        /// GET api/bom/stores
        /// Returns store/plant lookup options from STOREMST.
        /// </summary>
        [HttpGet("stores")]
        public async Task<IActionResult> GetStores()
        {
            var stores = await _service.GetStoresAsync();
            return Ok(ApiResponse<IEnumerable<BomStoreLookupDto>>.Ok(stores));
        }

        /// <summary>
        /// GET api/bom/departments
        /// Returns department lookup options from DEPTMST.
        /// </summary>
        [HttpGet("departments")]
        public async Task<IActionResult> GetDepartments()
        {
            var depts = await _service.GetDepartmentsAsync();
            return Ok(ApiResponse<IEnumerable<BomDepartmentLookupDto>>.Ok(depts));
        }

        /// <summary>
        /// GET api/bom/units
        /// Returns unit of measurement lookup options from UNITMST.
        /// </summary>
        [HttpGet("units")]
        public async Task<IActionResult> GetUnits()
        {
            var units = await _service.GetUnitsAsync();
            return Ok(ApiResponse<IEnumerable<BomUnitLookupDto>>.Ok(units));
        }

        /// <summary>
        /// GET api/bom/finished-goods?skuCross=J&query=...
        /// Returns Finished Goods items from ITEMMST filtered by SKU_CROSS.
        /// </summary>
        [HttpGet("finished-goods")]
        public async Task<IActionResult> GetFinishedGoods([FromQuery] string? skuCross, [FromQuery] string? query)
        {
            var fgItems = await _service.GetFinishedGoodsAsync(skuCross ?? string.Empty, query ?? string.Empty);
            return Ok(ApiResponse<IEnumerable<FinishedGoodLookupDto>>.Ok(fgItems));
        }

        /// <summary>
        /// GET api/bom/components?parentCode=...
        /// Returns raw materials, accessories, packaging, and WIP items from ITEMMST.
        /// </summary>
        [HttpGet("components")]
        public async Task<IActionResult> GetComponents([FromQuery] string? parentCode, [FromQuery] string? parent, [FromQuery] string? query)
        {
            var pCode = parentCode ?? parent ?? string.Empty;
            var components = await _service.GetComponentsAsync(pCode, query ?? string.Empty);
            return Ok(ApiResponse<IEnumerable<ComponentLookupDto>>.Ok(components));
        }

        /// <summary>
        /// GET api/bom or api/bom/records?mode=JOB&query=...
        /// Returns all BOM header summaries for the Show Record Lookup Modal.
        /// </summary>
        [HttpGet]
        [HttpGet("records")]
        public async Task<IActionResult> GetAll([FromQuery] string? mode, [FromQuery] string? query)
        {
            var summaries = await _service.GetAllSummariesAsync(mode, query);
            return Ok(ApiResponse<IEnumerable<BomRecordSummaryDto>>.Ok(summaries, "BOM records fetched successfully."));
        }

        /// <summary>
        /// GET api/bom/{bomId} or api/bom/details/{bomId}
        /// Returns full BOM record (Header + SubItems) for dual-pane population.
        /// </summary>
        [HttpGet("{*bomId}")]
        [HttpGet("details/{*bomId}")]
        public async Task<IActionResult> GetById(string bomId)
        {
            var record = await _service.GetByIdAsync(bomId);
            if (record == null)
            {
                return NotFound(ApiResponse<string>.Fail($"BOM record '{bomId}' not found."));
            }

            return Ok(ApiResponse<BomCompleteRecordDto>.Ok(record));
        }

        [HttpGet("details")]
        public async Task<IActionResult> GetDetailsByQuery([FromQuery] string bomId)
        {
            return await GetById(bomId);
        }

        /// <summary>
        /// POST api/bom or api/bom/save
        /// Inserts or updates BOM Master, Sub-Items, and DAYBOOK Audit Log within a single ACID SQL Transaction.
        /// </summary>
        [HttpPost]
        [HttpPost("save")]
        public async Task<IActionResult> SaveBom([FromBody] BomCompleteRecordDto payload)
        {
            if (payload == null || payload.Header == null || string.IsNullOrWhiteSpace(payload.Header.BomId))
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid BOM payload. Header and BOM ID are required."));
            }

            try
            {
                var success = await _service.SaveBomAsync(payload);
                if (!success)
                {
                    return StatusCode(500, ApiResponse<string>.Fail("Database transaction failed to save BOM."));
                }

                return Ok(ApiResponse<BomCompleteRecordDto>.Ok(payload, "BOM saved successfully."));
            }
            catch (Exception ex)
            {
                return StatusCode(500, ApiResponse<string>.Fail($"Failed to save BOM: {ex.Message}"));
            }
        }

        /// <summary>
        /// DELETE api/bom or api/bom/delete?bomId=...
        /// Deletes BOM Sub-Items and Master using query parameter (avoids slash encoding issues in URL path).
        /// </summary>
        [HttpDelete]
        [HttpDelete("delete")]
        public async Task<IActionResult> DeleteByQuery([FromQuery] string? bomId, [FromQuery] string? id)
        {
            var key = !string.IsNullOrWhiteSpace(bomId) ? bomId : id;
            if (string.IsNullOrWhiteSpace(key))
            {
                return BadRequest(ApiResponse<string>.Fail("BOM ID is required for deletion."));
            }

            key = Uri.UnescapeDataString(key).Trim();
            var deleted = await _service.DeleteBomAsync(key, User.Identity?.Name ?? "ADMIN");
            if (!deleted)
            {
                return NotFound(ApiResponse<string>.Fail($"BOM record '{key}' not found or already deleted."));
            }

            return Ok(ApiResponse<string>.Ok(key, $"BOM '{key}' deleted successfully."));
        }

        /// <summary>
        /// DELETE api/bom/{bomId}
        /// Deletes BOM Sub-Items and Master within an ACID SQL Transaction.
        /// </summary>
        [HttpDelete("{*bomId}")]
        public async Task<IActionResult> Delete(string bomId)
        {
            if (string.IsNullOrWhiteSpace(bomId))
            {
                return BadRequest(ApiResponse<string>.Fail("BOM ID is required."));
            }

            var key = Uri.UnescapeDataString(bomId).Trim();
            var deleted = await _service.DeleteBomAsync(key, User.Identity?.Name ?? "ADMIN");
            if (!deleted)
            {
                return NotFound(ApiResponse<string>.Fail($"BOM record '{key}' not found or already deleted."));
            }

            return Ok(ApiResponse<string>.Ok(key, $"BOM '{key}' deleted successfully."));
        }
    }
}
