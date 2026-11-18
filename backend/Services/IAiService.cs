using System.Threading.Tasks;
using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface IAiService
    {
        Task<AiChatResponseDto> ChatAsync(AiChatRequestDto request);
    }
}
