namespace MMSERP.Api.Models
{
    public class AuthAuditLog
    {
        public int LogId { get; set; }
        public int? UserId { get; set; }
        public string EventType { get; set; } = string.Empty;
        public string? IpAddress { get; set; }
        public string? DeviceInfo { get; set; }
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
        public bool Success { get; set; }
        public string? Detail { get; set; }
    }
}
