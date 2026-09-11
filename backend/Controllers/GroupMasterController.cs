using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class GroupMasterController : ControllerBase
    {
        private readonly IGroupMasterService _service;

        public GroupMasterController(IGroupMasterService service)
        {
            _service = service;
        }

        [HttpGet("GetAll")]
        public async Task<IActionResult> GetAll([FromQuery] string? search)
        {
            try
            {
                var items = await _service.GetAllAsync(search);
                return Ok(new { success = true, message = "Group records fetched successfully.", data = items });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpGet("GetByCode/{code}")]
        public async Task<IActionResult> GetByCode(string code)
        {
            try
            {
                var item = await _service.GetByCodeAsync(code);
                if (item == null)
                    return NotFound(new { success = false, message = "Group record not found." });

                return Ok(new { success = true, data = item });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpGet("GetNextCode")]
        public async Task<IActionResult> GetNextCode()
        {
            try
            {
                var nextCode = await _service.GetNextCodeAsync();
                return Ok(new { success = true, data = nextCode });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpGet("GetTaxSlabs")]
        public async Task<IActionResult> GetTaxSlabs()
        {
            try
            {
                var taxSlabs = await _service.GetTaxSlabsAsync();
                return Ok(new { success = true, data = taxSlabs });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpPost("Insert")]
        public async Task<IActionResult> Insert([FromBody] GroupMasterDto item)
        {
            try
            {
                if (!ModelState.IsValid)
                    return BadRequest(new { success = false, message = "Invalid data model." });

                var success = await _service.InsertAsync(item);
                if (success)
                    return Ok(new { success = true, message = "Group Master created successfully." });

                return BadRequest(new { success = false, message = "Failed to insert Group Master." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpPut("Update")]
        public async Task<IActionResult> Update([FromBody] GroupMasterDto item)
        {
            try
            {
                if (!ModelState.IsValid)
                    return BadRequest(new { success = false, message = "Invalid data model." });

                var success = await _service.UpdateAsync(item);
                if (success)
                    return Ok(new { success = true, message = "Group Master updated successfully." });

                return BadRequest(new { success = false, message = "Failed to update Group Master." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpDelete("Delete/{code}")]
        public async Task<IActionResult> Delete(string code)
        {
            try
            {
                var success = await _service.DeleteAsync(code);
                if (success)
                    return Ok(new { success = true, message = "Group Master deleted successfully." });

                return BadRequest(new { success = false, message = "Failed to delete Group Master." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }
    }
}
