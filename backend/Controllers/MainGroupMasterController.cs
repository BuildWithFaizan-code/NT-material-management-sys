using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class MainGroupMasterController : ControllerBase
    {
        private readonly IMainGroupMasterService _service;

        public MainGroupMasterController(IMainGroupMasterService service)
        {
            _service = service;
        }

        [HttpGet("GetAll")]
        public async Task<IActionResult> GetAll([FromQuery] string? search)
        {
            try
            {
                var data = await _service.GetAllAsync(search);
                return Ok(new
                {
                    success = true,
                    message = "Main Group records fetched successfully.",
                    data,
                    timestamp = DateTime.UtcNow
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    success = false,
                    message = $"Error fetching Main Group records: {ex.Message}"
                });
            }
        }

        [HttpGet("GetByCode/{code}")]
        public async Task<IActionResult> GetByCode(string code)
        {
            try
            {
                var item = await _service.GetByCodeAsync(code);
                if (item == null)
                {
                    return NotFound(new { success = false, message = $"Main Group record with code '{code}' not found." });
                }

                return Ok(new { success = true, data = item });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Error fetching record: {ex.Message}" });
            }
        }

        [HttpGet("GetNextCode")]
        public async Task<IActionResult> GetNextCode()
        {
            try
            {
                var nextCode = await _service.GetNextCodeAsync();
                return Ok(new
                {
                    success = true,
                    message = "Next Main Code generated successfully.",
                    data = nextCode,
                    timestamp = DateTime.UtcNow
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    success = false,
                    message = $"Error generating next Main Code: {ex.Message}"
                });
            }
        }

        [HttpPost("Insert")]
        public async Task<IActionResult> Insert([FromBody] MainGroupMasterDto item)
        {
            if (item == null || string.IsNullOrWhiteSpace(item.WipCode) || string.IsNullOrWhiteSpace(item.WipName))
            {
                return BadRequest(new { success = false, message = "Main Code and Main Name are required." });
            }

            try
            {
                var ok = await _service.InsertAsync(item);
                return Ok(new { success = ok, message = ok ? "Main Group inserted successfully." : "Insert failed." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Insert error: {ex.Message}" });
            }
        }

        [HttpPut("Update")]
        public async Task<IActionResult> Update([FromBody] MainGroupMasterDto item)
        {
            if (item == null || string.IsNullOrWhiteSpace(item.WipCode) || string.IsNullOrWhiteSpace(item.WipName))
            {
                return BadRequest(new { success = false, message = "Main Code and Main Name are required." });
            }

            try
            {
                var ok = await _service.UpdateAsync(item);
                return Ok(new { success = ok, message = ok ? "Main Group updated successfully." : "Update failed." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Update error: {ex.Message}" });
            }
        }

        [HttpDelete("Delete/{code}")]
        public async Task<IActionResult> Delete(string code)
        {
            try
            {
                var ok = await _service.DeleteAsync(code);
                return Ok(new { success = ok, message = ok ? "Main Group deleted successfully." : "Delete failed." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Delete error: {ex.Message}" });
            }
        }
    }
}
