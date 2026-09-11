using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class StoreMasterController : ControllerBase
    {
        private readonly IStoreMasterService _service;

        public StoreMasterController(IStoreMasterService service)
        {
            _service = service;
        }

        /// <summary>
        /// GET /api/storemaster
        /// Returns all store master records joined with location descriptions.
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var stores = await _service.GetAllAsync();
            return Ok(ApiResponse<IEnumerable<StoreMaster>>.Ok(
                stores,
                "Store Master records fetched successfully."));
        }

        /// <summary>
        /// GET /api/storemaster/locations
        /// Returns location lookup items for form dropdown selection.
        /// </summary>
        [HttpGet("locations")]
        public async Task<IActionResult> GetLocationLookup()
        {
            var locations = await _service.GetLocationLookupAsync();
            return Ok(ApiResponse<IEnumerable<LocationLookupDto>>.Ok(
                locations,
                "Location lookup list fetched successfully."));
        }

        /// <summary>
        /// GET /api/storemaster/next-code
        /// Returns next auto-incremented STR_CODE.
        /// </summary>
        [HttpGet("next-code")]
        public async Task<IActionResult> GetNextCode()
        {
            var nextCode = await _service.GetNextCodeAsync();
            return Ok(ApiResponse<int>.Ok(nextCode, "Next store code generated."));
        }

        /// <summary>
        /// POST /api/storemaster
        /// Inserts a new store record into STOREMST table.
        /// </summary>
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] StoreMaster model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.StrName))
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid store payload. Store name is required."));
            }

            var created = await _service.CreateAsync(model);
            if (!created)
            {
                return StatusCode(500, ApiResponse<string>.Fail("Failed to create Store Master record in database."));
            }

            return Ok(ApiResponse<StoreMaster>.Ok(
                model,
                "Store Master record created successfully."));
        }

        /// <summary>
        /// PUT /api/storemaster/{code}
        /// Updates an existing store record in STOREMST table.
        /// </summary>
        [HttpPut("{code:int}")]
        public async Task<IActionResult> Update(int code, [FromBody] StoreMaster model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.StrName))
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid store payload for update."));
            }

            var updated = await _service.UpdateAsync(code, model);
            if (!updated)
            {
                return NotFound(ApiResponse<string>.Fail($"Store Master record with code #{code} not found."));
            }

            model.StrCode = code;
            return Ok(ApiResponse<StoreMaster>.Ok(model, "Store Master record updated successfully."));
        }

        /// <summary>
        /// DELETE /api/storemaster/{code}
        /// Deletes a store record by STR_CODE.
        /// </summary>
        [HttpDelete("{code:int}")]
        public async Task<IActionResult> Delete(int code)
        {
            var deleted = await _service.DeleteAsync(code);
            if (!deleted)
            {
                return NotFound(ApiResponse<string>.Fail($"Store Master record with code #{code} not found."));
            }

            return Ok(ApiResponse<int>.Ok(code, $"Store Master record #{code} deleted successfully."));
        }
    }
}
