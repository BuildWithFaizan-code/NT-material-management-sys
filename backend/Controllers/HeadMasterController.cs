using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class HeadMasterController : ControllerBase
    {
        private readonly IHeadMasterService _service;

        public HeadMasterController(IHeadMasterService service)
        {
            _service = service;
        }

        /// <summary>
        /// GET /api/HeadMaster/GetAll
        /// Returns all costing head records (MODE = 'COSTING HEAD') from LOCATIONMST table.
        /// </summary>
        [HttpGet("GetAll")]
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var items = await _service.GetAllAsync();
            return Ok(ApiResponse<IEnumerable<HeadMasterDto>>.Ok(
                items,
                "Head Master (Costing Head) records fetched successfully."));
        }

        /// <summary>
        /// GET /api/HeadMaster/GetNextCode
        /// Returns next available auto LOC_CODE.
        /// </summary>
        [HttpGet("GetNextCode")]
        [HttpGet("next-code")]
        public async Task<IActionResult> GetNextCode()
        {
            var nextCode = await _service.GetNextCodeAsync();
            return Ok(ApiResponse<int>.Ok(nextCode, "Next Head Master code generated."));
        }

        /// <summary>
        /// GET /api/HeadMaster/{code}
        /// Returns single costing head record by code.
        /// </summary>
        [HttpGet("{code:int}")]
        public async Task<IActionResult> GetByCode(int code)
        {
            var item = await _service.GetByCodeAsync(code);
            if (item == null)
            {
                return NotFound(ApiResponse<string>.Fail($"Head Master record with code #{code} not found."));
            }
            return Ok(ApiResponse<HeadMasterDto>.Ok(item));
        }

        /// <summary>
        /// POST /api/HeadMaster/Create
        /// Creates a new costing head record in LOCATIONMST with MODE = 'COSTING HEAD'.
        /// </summary>
        [HttpPost("Create")]
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateHeadMasterDto model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.Location))
            {
                return BadRequest(ApiResponse<string>.Fail("Head Name (Location) is required."));
            }

            var success = await _service.CreateAsync(model);
            if (!success)
            {
                return BadRequest(ApiResponse<string>.Fail("Failed to create Head Master record."));
            }

            return Ok(ApiResponse<string>.Ok("Head Master saved to SQL Server successfully."));
        }

        /// <summary>
        /// PUT /api/HeadMaster/Update/{code}
        /// Updates an existing costing head record in LOCATIONMST.
        /// </summary>
        [HttpPut("Update/{code:int}")]
        [HttpPut("{code:int}")]
        public async Task<IActionResult> Update(int code, [FromBody] CreateHeadMasterDto model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.Location))
            {
                return BadRequest(ApiResponse<string>.Fail("Head Name (Location) is required."));
            }

            var success = await _service.UpdateAsync(code, model);
            if (!success)
            {
                return NotFound(ApiResponse<string>.Fail($"Head Master with code #{code} not found or update failed."));
            }

            return Ok(ApiResponse<string>.Ok("Head Master updated successfully."));
        }

        /// <summary>
        /// DELETE /api/HeadMaster/Delete/{code}
        /// Deletes a costing head record from LOCATIONMST.
        /// </summary>
        [HttpDelete("Delete/{code:int}")]
        [HttpDelete("{code:int}")]
        public async Task<IActionResult> Delete(int code)
        {
            var success = await _service.DeleteAsync(code);
            if (!success)
            {
                return NotFound(ApiResponse<string>.Fail($"Head Master with code #{code} not found or delete failed."));
            }

            return Ok(ApiResponse<string>.Ok("Head Master deleted successfully."));
        }
    }
}
