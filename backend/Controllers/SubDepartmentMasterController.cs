using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SubDepartmentMasterController : ControllerBase
    {
        private readonly ISubDepartmentMasterService _service;

        public SubDepartmentMasterController(ISubDepartmentMasterService service)
        {
            _service = service;
        }

        /// <summary>
        /// GET /api/SubDepartmentMaster/GetAll
        /// Returns all sub-department records from SUBDEPMST table.
        /// </summary>
        [HttpGet("GetAll")]
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var items = await _service.GetAllAsync();
            return Ok(ApiResponse<IEnumerable<SubDepartmentMasterDto>>.Ok(
                items,
                "Sub-Department Master records fetched successfully."));
        }

        /// <summary>
        /// GET /api/SubDepartmentMaster/GetNextCode
        /// Returns next available auto SDM_CODE.
        /// </summary>
        [HttpGet("GetNextCode")]
        [HttpGet("next-code")]
        public async Task<IActionResult> GetNextCode()
        {
            var nextCode = await _service.GetNextCodeAsync();
            return Ok(ApiResponse<int>.Ok(nextCode, "Next sub-department code generated."));
        }

        /// <summary>
        /// GET /api/SubDepartmentMaster/{code}
        /// Returns single sub-department by code.
        /// </summary>
        [HttpGet("{code:int}")]
        public async Task<IActionResult> GetByCode(int code)
        {
            var item = await _service.GetByCodeAsync(code);
            if (item == null)
            {
                return NotFound(ApiResponse<string>.Fail($"Sub-Department record with code #{code} not found."));
            }
            return Ok(ApiResponse<SubDepartmentMasterDto>.Ok(item));
        }

        /// <summary>
        /// POST /api/SubDepartmentMaster/Create
        /// Creates a new sub-department record in SUBDEPMST.
        /// </summary>
        [HttpPost("Create")]
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateSubDepartmentDto model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.SdmName))
            {
                return BadRequest(ApiResponse<string>.Fail("Sub-Department Name is required."));
            }

            var success = await _service.CreateAsync(model);
            if (!success)
            {
                return BadRequest(ApiResponse<string>.Fail("Failed to create sub-department record."));
            }

            return Ok(ApiResponse<string>.Ok("Sub-Department saved to SQL Server successfully."));
        }

        /// <summary>
        /// PUT /api/SubDepartmentMaster/Update/{code}
        /// Updates an existing sub-department record in SUBDEPMST.
        /// </summary>
        [HttpPut("Update/{code:int}")]
        [HttpPut("{code:int}")]
        public async Task<IActionResult> Update(int code, [FromBody] CreateSubDepartmentDto model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.SdmName))
            {
                return BadRequest(ApiResponse<string>.Fail("Sub-Department Name is required."));
            }

            var success = await _service.UpdateAsync(code, model);
            if (!success)
            {
                return NotFound(ApiResponse<string>.Fail($"Sub-Department with code #{code} not found or update failed."));
            }

            return Ok(ApiResponse<string>.Ok("Sub-Department updated successfully."));
        }

        /// <summary>
        /// DELETE /api/SubDepartmentMaster/Delete/{code}
        /// Deletes a sub-department record from SUBDEPMST.
        /// </summary>
        [HttpDelete("Delete/{code:int}")]
        [HttpDelete("{code:int}")]
        public async Task<IActionResult> Delete(int code)
        {
            var success = await _service.DeleteAsync(code);
            if (!success)
            {
                return NotFound(ApiResponse<string>.Fail($"Sub-Department with code #{code} not found or delete failed."));
            }

            return Ok(ApiResponse<string>.Ok("Sub-Department deleted successfully."));
        }
    }
}
