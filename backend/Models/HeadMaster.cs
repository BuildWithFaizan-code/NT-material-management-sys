namespace MMSERP.Api.Models
{
    public class HeadMasterDto
    {
        public int LocCode { get; set; }
        public string Location { get; set; } = string.Empty;
        public string Mode { get; set; } = "COSTING HEAD";
        public string? LocSeries { get; set; }
    }

    public class CreateHeadMasterDto
    {
        public int LocCode { get; set; }
        public string Location { get; set; } = string.Empty;
        public string? LocSeries { get; set; }
    }
}
