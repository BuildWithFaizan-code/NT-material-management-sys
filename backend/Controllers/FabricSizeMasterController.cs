using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class FabricSizeMasterController : ControllerBase
    {
        private readonly IFabricSizeMasterService _service;

        public FabricSizeMasterController(IFabricSizeMasterService service)
        {
            _service = service;
        }

        /// <summary>
        /// GET /api/FabricSizeMaster/GetAll
        /// </summary>
        [HttpGet("GetAll")]
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var items = await _service.GetAllAsync();
            return Ok(ApiResponse<IEnumerable<FabricSizeMasterDto>>.Ok(items, "Fabric sizes fetched successfully."));
        }

        /// <summary>
        /// GET /api/FabricSizeMaster/GetNextCode
        /// </summary>
        [HttpGet("GetNextCode")]
        public async Task<IActionResult> GetNextCode()
        {
            var code = await _service.GetNextCodeAsync();
            return Ok(ApiResponse<int>.Ok(code, "Next size code generated successfully."));
        }

        /// <summary>
        /// POST /api/FabricSizeMaster/Insert
        /// </summary>
        [HttpPost("Insert")]
        public async Task<IActionResult> Insert([FromBody] FabricSizeMasterDto dto)
        {
            var ok = await _service.InsertAsync(dto);
            if (ok)
            {
                return Ok(ApiResponse<string>.Ok("SUCCESS", "Fabric size created successfully."));
            }
            return BadRequest(ApiResponse<string>.Fail("Failed to create fabric size."));
        }

        /// <summary>
        /// PUT /api/FabricSizeMaster/Update
        /// </summary>
        [HttpPut("Update")]
        public async Task<IActionResult> Update([FromBody] FabricSizeMasterDto dto)
        {
            var ok = await _service.UpdateAsync(dto);
            if (ok)
            {
                return Ok(ApiResponse<string>.Ok("SUCCESS", "Fabric size updated successfully."));
            }
            return BadRequest(ApiResponse<string>.Fail("Failed to update fabric size."));
        }

        /// <summary>
        /// DELETE /api/FabricSizeMaster/Delete/{code}
        /// </summary>
        [HttpDelete("Delete/{code}")]
        public async Task<IActionResult> Delete(int code)
        {
            var ok = await _service.DeleteAsync(code);
            if (ok)
            {
                return Ok(ApiResponse<string>.Ok("SUCCESS", "Fabric size deleted successfully."));
            }
            return BadRequest(ApiResponse<string>.Fail("Failed to delete fabric size."));
        }
    }
}
