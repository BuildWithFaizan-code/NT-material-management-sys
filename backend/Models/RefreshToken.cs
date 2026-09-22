namespace MMSERP.Api.Models
{
    public class RefreshToken
    {
        public int TokenId { get; set; }
        public int UserId { get; set; }
        public string TokenHash { get; set; } = string.Empty;
        public string? DeviceInfo { get; set; }
        public string? IpAddress { get; set; }
        public DateTime IssuedAt { get; set; } = DateTime.UtcNow;
        public DateTime ExpiresAt { get; set; }
        public DateTime? RevokedAt { get; set; }
        public int? ReplacedByTokenId { get; set; }

        public bool IsActive => RevokedAt == null && DateTime.UtcNow < ExpiresAt;
    }
}
