namespace MMSERP.Api.Models
{
    public class LocationMaster
    {
        public int LocCode { get; set; }
        public string LocName { get; set; } = string.Empty;
        public string? LocPrefix { get; set; }
        public string? LocSeries { get; set; }
        public DateTime? CreatedDate { get; set; }
    }
}
