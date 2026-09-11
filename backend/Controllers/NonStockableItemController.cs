using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class NonStockableItemController : ControllerBase
    {
        private readonly INonStockableItemService _service;

        public NonStockableItemController(INonStockableItemService service)
        {
            _service = service;
        }

        /// <summary>
        /// GET /api/NonStockableItem/GetDropdowns
        /// Returns dropdown options for Units and Tax Slabs concurrently via Task.WhenAll.
        /// </summary>
        [HttpGet("GetDropdowns")]
        public async Task<IActionResult> GetDropdowns()
        {
            var data = await _service.GetDropdownsAsync();
            return Ok(ApiResponse<NonStockableDropdownsDto>.Ok(data, "Dropdown options fetched successfully."));
        }

        /// <summary>
        /// GET /api/NonStockableItem/GetUnassignedItems
        /// Returns items from ITEMMST that have not yet been configured in NONSTKITM.
        /// </summary>
        [HttpGet("GetUnassignedItems")]
        public async Task<IActionResult> GetUnassignedItems()
        {
            var items = await _service.GetUnassignedItemsAsync();
            return Ok(ApiResponse<IEnumerable<UnassignedItemDto>>.Ok(items, "Unassigned items fetched successfully."));
        }

        /// <summary>
        /// GET /api/NonStockableItem/GetAll
        /// Returns all configured non-stockable items from NONSTKITM.
        /// </summary>
        [HttpGet("GetAll")]
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var items = await _service.GetAllAsync();
            return Ok(ApiResponse<IEnumerable<NonStockableItemDto>>.Ok(items, "Non-stockable items fetched successfully."));
        }

        /// <summary>
        /// GET /api/NonStockableItem/{code}
        /// Returns single non-stockable item record by I_Code.
        /// </summary>
        [HttpGet("{code}")]
        public async Task<IActionResult> GetByCode(string code)
        {
            var item = await _service.GetByCodeAsync(code);
            if (item == null)
            {
                return NotFound(ApiResponse<string>.Fail($"Non-stockable item with code '{code}' not found."));
            }
            return Ok(ApiResponse<NonStockableItemDto>.Ok(item));
        }

        /// <summary>
        /// POST /api/NonStockableItem/Save
        /// Saves or updates a non-stockable item in NONSTKITM.
        /// </summary>
        [HttpPost("Save")]
        [HttpPost]
        public async Task<IActionResult> Save([FromBody] SaveNonStockableItemDto model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.ICode) || string.IsNullOrWhiteSpace(model.IName1))
            {
                return BadRequest(ApiResponse<string>.Fail("Item Code and Item Name are required."));
            }

            var success = await _service.SaveAsync(model);
            if (!success)
            {
                return BadRequest(ApiResponse<string>.Fail("Failed to save non-stockable item."));
            }

            return Ok(ApiResponse<string>.Ok("Non-stockable item saved successfully."));
        }

        /// <summary>
        /// DELETE /api/NonStockableItem/Delete/{code}
        /// Deletes a non-stockable item record from NONSTKITM.
        /// </summary>
        [HttpDelete("Delete/{code}")]
        [HttpDelete("{code}")]
        public async Task<IActionResult> Delete(string code)
        {
            var success = await _service.DeleteAsync(code);
            if (!success)
            {
                return NotFound(ApiResponse<string>.Fail($"Non-stockable item with code '{code}' not found or delete failed."));
            }
            return Ok(ApiResponse<string>.Ok("Non-stockable item deleted successfully."));
        }
    }
}
