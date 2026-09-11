using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class LocationMasterController : ControllerBase
    {
        private readonly ILocationMasterService _service;

        public LocationMasterController(ILocationMasterService service)
        {
            _service = service;
        }

        /// <summary>
        /// GET /api/locationmaster
        /// Returns all locations ordered by LOC_CODE.
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var locations = await _service.GetAllAsync();
            return Ok(ApiResponse<IEnumerable<LocationMaster>>.Ok(
                locations,
                "Location Master records fetched successfully."));
        }

        /// <summary>
        /// GET /api/locationmaster/{code}
        /// Returns single location by code.
        /// </summary>
        [HttpGet("{code:int}")]
        public async Task<IActionResult> GetByCode(int code)
        {
            var location = await _service.GetByCodeAsync(code);
            if (location == null)
            {
                return NotFound(ApiResponse<string>.Fail($"Location record with code #{code} not found."));
            }
            return Ok(ApiResponse<LocationMaster>.Ok(location, "Location record fetched."));
        }

        /// <summary>
        /// GET /api/locationmaster/next-code
        /// Returns next available auto LOC_CODE.
        /// </summary>
        [HttpGet("next-code")]
        public async Task<IActionResult> GetNextCode()
        {
            var nextCode = await _service.GetNextCodeAsync();
            return Ok(ApiResponse<int>.Ok(nextCode, "Next location code generated."));
        }

        /// <summary>
        /// POST /api/locationmaster
        /// Inserts new location record into LOCMST table.
        /// </summary>
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] LocationMaster model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.LocName))
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid location payload. Location name is required."));
            }

            var created = await _service.CreateAsync(model);
            if (!created)
            {
                return StatusCode(500, ApiResponse<string>.Fail("Failed to create Location Master record in database."));
            }

            return CreatedAtAction(nameof(GetByCode), new { code = model.LocCode }, ApiResponse<LocationMaster>.Ok(
                model,
                "Location Master created successfully."));
        }

        /// <summary>
        /// PUT /api/locationmaster/{code}
        /// Updates existing location record in LOCMST table.
        /// </summary>
        [HttpPut("{code:int}")]
        public async Task<IActionResult> Update(int code, [FromBody] LocationMaster model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.LocName))
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid location payload for update."));
            }

            var updated = await _service.UpdateAsync(code, model);
            if (!updated)
            {
                return NotFound(ApiResponse<string>.Fail($"Location Master record with code #{code} not found."));
            }

            model.LocCode = code;
            return Ok(ApiResponse<LocationMaster>.Ok(model, "Location Master updated successfully."));
        }

        /// <summary>
        /// DELETE /api/locationmaster/{code}
        /// Deletes location record by LOC_CODE.
        /// </summary>
        [HttpDelete("{code:int}")]
        public async Task<IActionResult> Delete(int code)
        {
            var deleted = await _service.DeleteAsync(code);
            if (!deleted)
            {
                return NotFound(ApiResponse<string>.Fail($"Location Master record with code #{code} not found."));
            }

            return Ok(ApiResponse<int>.Ok(code, $"Location Master record #{code} deleted successfully."));
        }
    }
}
