using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ChargesMasterController : ControllerBase
    {
        private readonly IChargesMasterService _service;

        public ChargesMasterController(IChargesMasterService service)
        {
            _service = service;
        }

        /// <summary>
        /// GET /api/ChargesMaster/GetAll?module=PURCHASE ORDER&mode=LOCAL
        /// Returns Charges Master list filtered by Module and Mode.
        /// </summary>
        [HttpGet("GetAll")]
        [HttpGet]
        public async Task<IActionResult> GetAll([FromQuery] string? module, [FromQuery] string? mode)
        {
            var items = await _service.GetAllAsync(module, mode);
            return Ok(ApiResponse<IEnumerable<ChargesMasterDto>>.Ok(items, "Charges Master list fetched successfully."));
        }

        /// <summary>
        /// POST /api/ChargesMaster/SaveAll
        /// Saves or updates Charges Master items.
        /// </summary>
        [HttpPost("SaveAll")]
        public async Task<IActionResult> SaveAll([FromBody] IEnumerable<ChargesMasterDto> items)
        {
            var result = await _service.SaveAllAsync(items);
            if (result)
            {
                return Ok(ApiResponse<string>.Ok("SUCCESS", "Charges Master records saved successfully."));
            }
            return BadRequest(ApiResponse<string>.Fail("Failed to save Charges Master records."));
        }
    }
}
