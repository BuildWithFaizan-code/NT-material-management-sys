using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class MakersMasterController : ControllerBase
    {
        private readonly IMakersMasterService _service;

        public MakersMasterController(IMakersMasterService service)
        {
            _service = service;
        }

        /// <summary>
        /// GET /api/MakersMaster/GetAll
        /// </summary>
        [HttpGet("GetAll")]
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var items = await _service.GetAllAsync();
            return Ok(ApiResponse<IEnumerable<MakersMasterDto>>.Ok(items, "Makers fetched successfully."));
        }

        /// <summary>
        /// GET /api/MakersMaster/GetNextCode
        /// </summary>
        [HttpGet("GetNextCode")]
        public async Task<IActionResult> GetNextCode()
        {
            var code = await _service.GetNextCodeAsync();
            return Ok(ApiResponse<int>.Ok(code, "Next maker code generated successfully."));
        }

        /// <summary>
        /// POST /api/MakersMaster/Insert
        /// </summary>
        [HttpPost("Insert")]
        public async Task<IActionResult> Insert([FromBody] MakersMasterDto dto)
        {
            var ok = await _service.InsertAsync(dto);
            if (ok)
            {
                return Ok(ApiResponse<string>.Ok("SUCCESS", "Maker created successfully."));
            }
            return BadRequest(ApiResponse<string>.Fail("Failed to create maker."));
        }

        /// <summary>
        /// PUT /api/MakersMaster/Update
        /// </summary>
        [HttpPut("Update")]
        public async Task<IActionResult> Update([FromBody] MakersMasterDto dto)
        {
            var ok = await _service.UpdateAsync(dto);
            if (ok)
            {
                return Ok(ApiResponse<string>.Ok("SUCCESS", "Maker updated successfully."));
            }
            return BadRequest(ApiResponse<string>.Fail("Failed to update maker."));
        }

        /// <summary>
        /// DELETE /api/MakersMaster/Delete/{code}
        /// </summary>
        [HttpDelete("Delete/{code}")]
        public async Task<IActionResult> Delete(int code)
        {
            var ok = await _service.DeleteAsync(code);
            if (ok)
            {
                return Ok(ApiResponse<string>.Ok("SUCCESS", "Maker deleted successfully."));
            }
            return BadRequest(ApiResponse<string>.Fail("Failed to delete maker."));
        }
    }
}
