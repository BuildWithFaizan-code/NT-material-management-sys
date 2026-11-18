using System.Collections.Generic;

namespace MMSERP.Api.Models
{
    public class ChatMessageDto
    {
        public string Role { get; set; } = "user"; // "user" or "model"
        public string Content { get; set; } = string.Empty;
    }

    public class AiChatRequestDto
    {
        public string Message { get; set; } = string.Empty;
        public List<ChatMessageDto> History { get; set; } = new();
        public string? ClientApiKey { get; set; }
    }

    public class AiChatResponseDto
    {
        public string Reply { get; set; } = string.Empty;
        public string Model { get; set; } = "gemini-1.5-flash";
        public bool IsLiveGemini { get; set; }
    }
}
