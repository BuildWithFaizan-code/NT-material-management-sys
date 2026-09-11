using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class OperatorMasterController : ControllerBase
    {
        private readonly IOperatorMasterService _service;

        public OperatorMasterController(IOperatorMasterService service)
        {
            _service = service;
        }

        /// <summary>
        /// GET /api/OperatorMaster/GetDepartments
        /// Returns list of departments from LABOURMST table.
        /// </summary>
        [HttpGet("GetDepartments")]
        public async Task<IActionResult> GetDepartments()
        {
            var departments = await _service.GetDepartmentsAsync();
            return Ok(ApiResponse<IEnumerable<DepartmentDto>>.Ok(
                departments,
                "Department records fetched successfully."));
        }

        /// <summary>
        /// GET /api/OperatorMaster/GetAll
        /// Returns all operators ordered by OPER_CODE.
        /// </summary>
        [HttpGet("GetAll")]
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var operators = await _service.GetAllAsync();
            return Ok(ApiResponse<IEnumerable<OperatorMasterDto>>.Ok(
                operators,
                "Operator Master records fetched successfully."));
        }

        /// <summary>
        /// GET /api/OperatorMaster/GetNextCode
        /// Returns next available auto OPER_CODE.
        /// </summary>
        [HttpGet("GetNextCode")]
        [HttpGet("next-code")]
        public async Task<IActionResult> GetNextCode()
        {
            var nextCode = await _service.GetNextCodeAsync();
            return Ok(ApiResponse<int>.Ok(nextCode, "Next operator code generated."));
        }

        /// <summary>
        /// GET /api/OperatorMaster/{code}
        /// Returns single operator by code.
        /// </summary>
        [HttpGet("{code:int}")]
        public async Task<IActionResult> GetByCode(int code)
        {
            var oper = await _service.GetByCodeAsync(code);
            if (oper == null)
            {
                return NotFound(ApiResponse<string>.Fail($"Operator record with code #{code} not found."));
            }
            return Ok(ApiResponse<OperatorMasterDto>.Ok(oper, "Operator record fetched."));
        }

        /// <summary>
        /// POST /api/OperatorMaster/Create
        /// Inserts new operator record into OPERATORMST table.
        /// </summary>
        [HttpPost("Create")]
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateOperatorDto model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.OperName))
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid operator payload. Operator name is required."));
            }

            if (model.OperDepCd <= 0)
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid department selected. Department selection is required."));
            }

            var created = await _service.CreateAsync(model);
            if (!created)
            {
                return StatusCode(500, ApiResponse<string>.Fail("Failed to create Operator Master record in database."));
            }

            return CreatedAtAction(nameof(GetByCode), new { code = model.OperCode }, ApiResponse<CreateOperatorDto>.Ok(
                model,
                "Operator Master created successfully."));
        }

        /// <summary>
        /// PUT /api/OperatorMaster/Update/{code}
        /// Updates existing operator record in OPERATORMST table.
        /// </summary>
        [HttpPut("Update/{code:int}")]
        [HttpPut("{code:int}")]
        public async Task<IActionResult> Update(int code, [FromBody] CreateOperatorDto model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.OperName))
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid operator payload for update."));
            }

            if (model.OperDepCd <= 0)
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid department selected. Department selection is required."));
            }

            model.OperCode = code;
            var updated = await _service.UpdateAsync(code, model);
            if (!updated)
            {
                return NotFound(ApiResponse<string>.Fail($"Operator Master record with code #{code} not found."));
            }

            return Ok(ApiResponse<CreateOperatorDto>.Ok(model, "Operator Master updated successfully."));
        }

        /// <summary>
        /// DELETE /api/OperatorMaster/Delete/{code}
        /// Deletes operator record by ID.
        /// </summary>
        [HttpDelete("Delete/{code:int}")]
        [HttpDelete("{code:int}")]
        public async Task<IActionResult> Delete(int code)
        {
            var deleted = await _service.DeleteAsync(code);
            if (!deleted)
            {
                return NotFound(ApiResponse<string>.Fail($"Operator Master record with code #{code} not found."));
            }

            return Ok(ApiResponse<string>.Ok($"Operator Master record #{code} deleted successfully.", "Operator deleted."));
        }
    }
}
