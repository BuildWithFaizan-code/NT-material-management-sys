using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Common;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AiController : ControllerBase
    {
        private readonly IAiService _aiService;

        public AiController(IAiService aiService)
        {
            _aiService = aiService;
        }

        [HttpPost("chat")]
        public async Task<IActionResult> Chat([FromBody] AiChatRequestDto request)
        {
            if (string.IsNullOrWhiteSpace(request?.Message))
            {
                return BadRequest(ApiResponse<AiChatResponseDto>.Fail("Prompt message cannot be empty."));
            }

            var response = await _aiService.ChatAsync(request);
            return Ok(ApiResponse<AiChatResponseDto>.Ok(response));
        }
    }
}
