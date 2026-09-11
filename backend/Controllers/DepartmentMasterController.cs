using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class DepartmentMasterController : ControllerBase
    {
        private readonly IDepartmentMasterService _service;

        public DepartmentMasterController(IDepartmentMasterService service)
        {
            _service = service;
        }

        /// <summary>
        /// GET /api/DepartmentMaster/GetAll
        /// Returns all department records from LABOURMST table.
        /// </summary>
        [HttpGet("GetAll")]
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var departments = await _service.GetAllAsync();
            return Ok(ApiResponse<IEnumerable<DepartmentMasterDto>>.Ok(
                departments,
                "Department Master records fetched successfully."));
        }

        /// <summary>
        /// GET /api/DepartmentMaster/GetAccounts
        /// Returns party accounts list from PARTYMST table.
        /// </summary>
        [HttpGet("GetAccounts")]
        public async Task<IActionResult> GetAccounts()
        {
            var accounts = await _service.GetAccountsAsync();
            return Ok(ApiResponse<IEnumerable<PartyAccountDto>>.Ok(
                accounts,
                "Party Account records fetched successfully."));
        }

        /// <summary>
        /// GET /api/DepartmentMaster/GetAccountsLookup?search={query}
        /// Returns detailed party account records matching real-time search query.
        /// </summary>
        [HttpGet("GetAccountsLookup")]
        public async Task<IActionResult> GetAccountsLookup([FromQuery] string? search)
        {
            var accounts = await _service.GetAccountsLookupAsync(search ?? string.Empty);
            return Ok(ApiResponse<IEnumerable<PartyAccountLookupDto>>.Ok(
                accounts,
                "Party Account lookup records fetched successfully."));
        }

        /// <summary>
        /// GET /api/DepartmentMaster/GetNextCode
        /// Returns next available auto LAB_CODE.
        /// </summary>
        [HttpGet("GetNextCode")]
        [HttpGet("next-code")]
        public async Task<IActionResult> GetNextCode()
        {
            var nextCode = await _service.GetNextCodeAsync();
            return Ok(ApiResponse<int>.Ok(nextCode, "Next department code generated."));
        }

        /// <summary>
        /// GET /api/DepartmentMaster/{code}
        /// Returns single department by code.
        /// </summary>
        [HttpGet("{code:int}")]
        public async Task<IActionResult> GetByCode(int code)
        {
            var dept = await _service.GetByCodeAsync(code);
            if (dept == null)
            {
                return NotFound(ApiResponse<string>.Fail($"Department record with code #{code} not found."));
            }
            return Ok(ApiResponse<DepartmentMasterDto>.Ok(dept, "Department record fetched."));
        }

        /// <summary>
        /// POST /api/DepartmentMaster/Create
        /// Inserts new department record into LABOURMST table.
        /// </summary>
        [HttpPost("Create")]
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateDepartmentDto model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.LabName))
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid department payload. Department name is required."));
            }

            var created = await _service.CreateAsync(model);
            if (!created)
            {
                return StatusCode(500, ApiResponse<string>.Fail("Failed to create Department Master record in database."));
            }

            return CreatedAtAction(nameof(GetByCode), new { code = model.LabCode }, ApiResponse<CreateDepartmentDto>.Ok(
                model,
                "Department Master created successfully."));
        }

        /// <summary>
        /// PUT /api/DepartmentMaster/Update/{code}
        /// Updates existing department record in LABOURMST table.
        /// </summary>
        [HttpPut("Update/{code:int}")]
        [HttpPut("{code:int}")]
        public async Task<IActionResult> Update(int code, [FromBody] CreateDepartmentDto model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.LabName))
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid department payload for update."));
            }

            model.LabCode = code;
            var updated = await _service.UpdateAsync(code, model);
            if (!updated)
            {
                return NotFound(ApiResponse<string>.Fail($"Department Master record with code #{code} not found."));
            }

            return Ok(ApiResponse<CreateDepartmentDto>.Ok(model, "Department Master updated successfully."));
        }

        /// <summary>
        /// DELETE /api/DepartmentMaster/Delete/{code}
        /// Deletes department record by ID.
        /// </summary>
        [HttpDelete("Delete/{code:int}")]
        [HttpDelete("{code:int}")]
        public async Task<IActionResult> Delete(int code)
        {
            var deleted = await _service.DeleteAsync(code);
            if (!deleted)
            {
                return NotFound(ApiResponse<string>.Fail($"Department Master record with code #{code} not found."));
            }

            return Ok(ApiResponse<string>.Ok($"Department Master record #{code} deleted successfully.", "Department deleted."));
        }
    }
}
