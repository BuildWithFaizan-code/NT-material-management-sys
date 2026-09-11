namespace MMSERP.Api.Models
{
    public class StoreMaster
    {
        public int StrCode { get; set; }
        public string StrName { get; set; } = string.Empty;
        public int LocCode { get; set; }
        public string? LocationName { get; set; }
        public string? StrSeries { get; set; }
        public string? StrFixChar { get; set; }
    }
}
