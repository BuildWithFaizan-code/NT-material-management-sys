namespace MMSERP.Api.Models
{
    public class LocationLookupDto
    {
        public int LocCode { get; set; }
        public string LocationName { get; set; } = string.Empty;
        public string Location { get => LocationName; set => LocationName = value; }
    }
}
