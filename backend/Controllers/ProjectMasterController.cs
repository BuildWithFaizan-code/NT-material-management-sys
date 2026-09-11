using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ProjectMasterController : ControllerBase
    {
        private readonly IProjectMasterService _service;

        public ProjectMasterController(IProjectMasterService service)
        {
            _service = service;
        }

        /// <summary>
        /// GET api/projectmaster
        /// Returns all Project Master records ordered by PRJ_CODE.
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var projects = await _service.GetAllAsync();
            return Ok(ApiResponse<IEnumerable<ProjectMasterDto>>.Ok(
                projects,
                "Project Master records fetched successfully."));
        }

        /// <summary>
        /// GET api/projectmaster/next-code
        /// Returns the next available PRJ_CODE.
        /// </summary>
        [HttpGet("next-code")]
        public async Task<IActionResult> GetNextCode()
        {
            var nextCode = await _service.GetNextCodeAsync();
            return Ok(ApiResponse<int>.Ok(
                nextCode,
                "Next project code generated."));
        }

        /// <summary>
        /// POST api/projectmaster
        /// Creates a new Project Master record.
        /// </summary>
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] ProjectMasterDto dto)
        {
            if (dto == null || string.IsNullOrWhiteSpace(dto.PrjName))
            {
                return BadRequest(ApiResponse<string>.Fail(
                    "Invalid project payload. Project description is required."));
            }

            var created = await _service.CreateAsync(dto);
            if (!created)
            {
                return StatusCode(500, ApiResponse<string>.Fail(
                    "Failed to create Project Master record in database."));
            }

            return CreatedAtAction(nameof(GetAll), ApiResponse<ProjectMasterDto>.Ok(
                dto,
                "Project Master created successfully."));
        }

        /// <summary>
        /// PUT api/projectmaster
        /// Updates an existing Project Master record.
        /// </summary>
        [HttpPut]
        public async Task<IActionResult> Update([FromBody] ProjectMasterDto dto)
        {
            if (dto == null || dto.PrjCode <= 0 || string.IsNullOrWhiteSpace(dto.PrjName))
            {
                return BadRequest(ApiResponse<string>.Fail(
                    "Invalid project payload for update."));
            }

            var updated = await _service.UpdateAsync(dto);
            if (!updated)
            {
                return NotFound(ApiResponse<string>.Fail(
                    $"Project Master record with Code #{dto.PrjCode} not found."));
            }

            return Ok(ApiResponse<ProjectMasterDto>.Ok(
                dto,
                "Project Master updated successfully."));
        }

        /// <summary>
        /// DELETE api/projectmaster/{code}
        /// Deletes a Project Master record by PRJ_CODE.
        /// </summary>
        [HttpDelete("{code:int}")]
        public async Task<IActionResult> Delete(int code)
        {
            var deleted = await _service.DeleteAsync(code);
            if (!deleted)
            {
                return NotFound(ApiResponse<string>.Fail(
                    $"Project Master record with Code #{code} not found."));
            }

            return Ok(ApiResponse<int>.Ok(
                code,
                $"Project Master record #{code} deleted successfully."));
        }
    }
}
