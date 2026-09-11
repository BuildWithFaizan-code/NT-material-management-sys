using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class GroupMasterDefinitionController : ControllerBase
    {
        private readonly IGroupMasterDefinitionService _service;

        public GroupMasterDefinitionController(IGroupMasterDefinitionService service)
        {
            _service = service;
        }

        [HttpGet("GetMappedDefinitions")]
        public async Task<IActionResult> GetMappedDefinitions([FromQuery] string? mCode)
        {
            try
            {
                var items = await _service.GetMappedDefinitionsAsync(mCode);
                return Ok(new { success = true, message = "Mapped group definitions fetched successfully.", data = items });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpGet("GetByMsCode/{msCode}")]
        public async Task<IActionResult> GetByMsCode(string msCode)
        {
            try
            {
                var item = await _service.GetByMsCodeAsync(msCode);
                if (item == null)
                    return NotFound(new { success = false, message = "Group definition record not found." });

                return Ok(new { success = true, data = item });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpGet("GetCategories")]
        public async Task<IActionResult> GetCategories()
        {
            try
            {
                var categories = await _service.GetCategoriesAsync();
                return Ok(new { success = true, data = categories });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpGet("GetMainGroups")]
        public async Task<IActionResult> GetMainGroups()
        {
            try
            {
                var mainGroups = await _service.GetMainGroupsAsync();
                return Ok(new { success = true, data = mainGroups });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpGet("GetMainGroupName/{mCode}")]
        public async Task<IActionResult> GetMainGroupName(string mCode)
        {
            try
            {
                var wipName = await _service.GetMainGroupNameByCodeAsync(mCode);
                return Ok(new { success = true, data = wipName ?? "" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpPost("Insert")]
        public async Task<IActionResult> Insert([FromBody] GroupMasterDefinitionDto dto)
        {
            try
            {
                if (!ModelState.IsValid)
                    return BadRequest(new { success = false, message = "Invalid data model." });

                if (string.IsNullOrWhiteSpace(dto.IsmMsCode))
                {
                    dto.IsmMsCode = $"{dto.IsmMCode.Trim()}{dto.IsmSubCode.Trim()}";
                }

                var success = await _service.InsertAsync(dto);
                if (success)
                    return Ok(new { success = true, message = "Group Definition mapping created successfully." });

                return BadRequest(new { success = false, message = "Failed to insert Group Definition mapping." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpPut("Update")]
        public async Task<IActionResult> Update([FromBody] GroupMasterDefinitionDto dto)
        {
            try
            {
                if (!ModelState.IsValid)
                    return BadRequest(new { success = false, message = "Invalid data model." });

                var success = await _service.UpdateAsync(dto);
                if (success)
                    return Ok(new { success = true, message = "Group Definition mapping updated successfully." });

                return BadRequest(new { success = false, message = "Failed to update Group Definition mapping." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        [HttpDelete("Delete/{msCode}")]
        public async Task<IActionResult> Delete(string msCode)
        {
            try
            {
                var success = await _service.DeleteAsync(msCode);
                if (success)
                    return Ok(new { success = true, message = "Group Definition mapping deleted successfully." });

                return BadRequest(new { success = false, message = "Failed to delete Group Definition mapping." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }
    }
}
