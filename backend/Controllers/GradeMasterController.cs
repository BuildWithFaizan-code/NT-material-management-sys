using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class GradeMasterController : ControllerBase
    {
        private readonly IGradeMasterService _service;

        public GradeMasterController(IGradeMasterService service)
        {
            _service = service;
        }

        [HttpGet("GetAll")]
        public async Task<IActionResult> GetAll()
        {
            try
            {
                var data = await _service.GetAllAsync();
                return Ok(new
                {
                    success = true,
                    message = "Grade records fetched successfully.",
                    data,
                    timestamp = DateTime.UtcNow
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    success = false,
                    message = $"Error fetching grade records: {ex.Message}"
                });
            }
        }

        [HttpGet("GetNextSrl")]
        public async Task<IActionResult> GetNextSrl()
        {
            try
            {
                var nextSrl = await _service.GetNextSrlAsync();
                return Ok(new
                {
                    success = true,
                    data = nextSrl
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    success = false,
                    message = $"Error fetching next grade serial: {ex.Message}"
                });
            }
        }

        [HttpPost("Insert")]
        public async Task<IActionResult> Insert([FromBody] GradeMasterDto item)
        {
            if (item == null || string.IsNullOrWhiteSpace(item.GradeCode))
            {
                return BadRequest(new { success = false, message = "Grade Code is required." });
            }

            try
            {
                var ok = await _service.InsertAsync(item);
                return Ok(new { success = ok, message = ok ? "Grade record inserted successfully." : "Insert failed." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Insert error: {ex.Message}" });
            }
        }

        [HttpPut("Update")]
        public async Task<IActionResult> Update([FromBody] GradeMasterDto item)
        {
            if (item == null || item.GradeSrl <= 0 || string.IsNullOrWhiteSpace(item.GradeCode))
            {
                return BadRequest(new { success = false, message = "Valid Grade Serial and Code are required." });
            }

            try
            {
                var ok = await _service.UpdateAsync(item);
                return Ok(new { success = ok, message = ok ? "Grade record updated successfully." : "Update failed." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Update error: {ex.Message}" });
            }
        }

        [HttpDelete("Delete/{gradeSrl}")]
        public async Task<IActionResult> Delete(int gradeSrl)
        {
            if (gradeSrl <= 0)
            {
                return BadRequest(new { success = false, message = "Invalid grade serial." });
            }

            try
            {
                var ok = await _service.DeleteAsync(gradeSrl);
                return Ok(new { success = ok, message = ok ? "Grade record deleted successfully." : "Delete failed." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Delete error: {ex.Message}" });
            }
        }
    }
}
