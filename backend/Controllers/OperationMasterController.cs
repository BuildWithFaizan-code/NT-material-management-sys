using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class OperationMasterController : ControllerBase
    {
        private readonly IOperationMasterService _service;

        public OperationMasterController(IOperationMasterService service)
        {
            _service = service;
        }

        /// <summary>
        /// GET /api/OperationMaster/GetAll
        /// Returns all operations ordered by OM_CODE DESC.
        /// </summary>
        [HttpGet("GetAll")]
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var operations = await _service.GetAllAsync();
            return Ok(ApiResponse<IEnumerable<OperationMasterDto>>.Ok(
                operations,
                "Operation Master records fetched successfully."));
        }

        /// <summary>
        /// GET /api/OperationMaster/GetNextCode
        /// Returns next available auto OM_CODE.
        /// </summary>
        [HttpGet("GetNextCode")]
        [HttpGet("next-code")]
        public async Task<IActionResult> GetNextCode()
        {
            var nextCode = await _service.GetNextCodeAsync();
            return Ok(ApiResponse<int>.Ok(nextCode, "Next operation code generated."));
        }

        /// <summary>
        /// GET /api/OperationMaster/{code}
        /// Returns single operation by code.
        /// </summary>
        [HttpGet("{code:int}")]
        public async Task<IActionResult> GetByCode(int code)
        {
            var oper = await _service.GetByCodeAsync(code);
            if (oper == null)
            {
                return NotFound(ApiResponse<string>.Fail($"Operation record with code #{code} not found."));
            }
            return Ok(ApiResponse<OperationMasterDto>.Ok(oper, "Operation record fetched."));
        }

        /// <summary>
        /// POST /api/OperationMaster/Create
        /// Inserts new operation record into OPERATION_MST table.
        /// </summary>
        [HttpPost("Create")]
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateOperationDto model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.OmDesc))
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid operation payload. Operation description is required."));
            }

            if (model.OmFixRate < 0)
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid fixed rate. Rate must be greater than or equal to 0."));
            }

            var created = await _service.CreateAsync(model);
            if (!created)
            {
                return StatusCode(500, ApiResponse<string>.Fail("Failed to create Operation Master record in database."));
            }

            return CreatedAtAction(nameof(GetByCode), new { code = model.OmCode }, ApiResponse<CreateOperationDto>.Ok(
                model,
                "Operation Master created successfully."));
        }

        /// <summary>
        /// PUT /api/OperationMaster/Update/{id}
        /// Updates existing operation record in OPERATION_MST table.
        /// </summary>
        [HttpPut("Update/{id:int}")]
        [HttpPut("{id:int}")]
        public async Task<IActionResult> Update(int id, [FromBody] CreateOperationDto model)
        {
            if (model == null || string.IsNullOrWhiteSpace(model.OmDesc))
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid operation payload. Operation description is required."));
            }

            if (model.OmFixRate < 0)
            {
                return BadRequest(ApiResponse<string>.Fail("Invalid fixed rate. Rate must be greater than or equal to 0."));
            }

            var updated = await _service.UpdateAsync(id, model);
            if (!updated)
            {
                return NotFound(ApiResponse<string>.Fail($"Operation record with code #{id} not found or update failed."));
            }

            return Ok(ApiResponse<CreateOperationDto>.Ok(model, "Operation Master updated successfully."));
        }

        /// <summary>
        /// DELETE /api/OperationMaster/Delete/{id}
        /// Deletes operation record from OPERATION_MST table.
        /// </summary>
        [HttpDelete("Delete/{id:int}")]
        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var deleted = await _service.DeleteAsync(id);
            if (!deleted)
            {
                return NotFound(ApiResponse<string>.Fail($"Operation record with code #{id} not found or delete failed."));
            }

            return Ok(ApiResponse<string>.Ok($"Operation #${id} deleted successfully."));
        }
    }
}
