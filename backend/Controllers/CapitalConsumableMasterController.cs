using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class CapitalConsumableMasterController : ControllerBase
    {
        private readonly ICapitalConsumableMasterService _service;

        public CapitalConsumableMasterController(ICapitalConsumableMasterService service)
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
                    message = "Capital / Consumable items fetched successfully.",
                    data,
                    timestamp = DateTime.UtcNow
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    success = false,
                    message = $"Error fetching records: {ex.Message}"
                });
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
                    data = nextCode
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    success = false,
                    message = $"Error fetching next code: {ex.Message}"
                });
            }
        }

        [HttpPost("Insert")]
        public async Task<IActionResult> Insert([FromBody] CapitalConsumableMasterDto item)
        {
            if (item == null || string.IsNullOrWhiteSpace(item.Name))
            {
                return BadRequest(new { success = false, message = "Capital / Consumable Name is required." });
            }

            try
            {
                var ok = await _service.InsertAsync(item);
                return Ok(new { success = ok, message = ok ? "Item inserted successfully." : "Insert failed." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Insert error: {ex.Message}" });
            }
        }

        [HttpPut("Update")]
        public async Task<IActionResult> Update([FromBody] CapitalConsumableMasterDto item)
        {
            if (item == null || item.Code <= 0 || string.IsNullOrWhiteSpace(item.Name))
            {
                return BadRequest(new { success = false, message = "Valid Code and Name are required." });
            }

            try
            {
                var ok = await _service.UpdateAsync(item);
                return Ok(new { success = ok, message = ok ? "Item updated successfully." : "Update failed." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Update error: {ex.Message}" });
            }
        }

        [HttpDelete("Delete/{code}")]
        public async Task<IActionResult> Delete(int code)
        {
            if (code <= 0)
            {
                return BadRequest(new { success = false, message = "Invalid code." });
            }

            try
            {
                var ok = await _service.DeleteAsync(code);
                return Ok(new { success = ok, message = ok ? "Item deleted successfully." : "Delete failed." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Delete error: {ex.Message}" });
            }
        }
    }
}
