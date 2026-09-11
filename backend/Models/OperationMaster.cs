namespace MMSERP.Api.Models
{
    public class OperationMaster
    {
        public int OmCode { get; set; }
        public string OmDesc { get; set; } = string.Empty;
        public decimal OmFixRate { get; set; }
        public string OmUser { get; set; } = "ADMIN";
        public DateTime? OmUserDtTime { get; set; }
    }

    public class OperationMasterDto
    {
        public int OmCode { get; set; }
        public string OmDesc { get; set; } = string.Empty;
        public decimal OmFixRate { get; set; }
        public string? OmUser { get; set; }
        public DateTime? OmUserDtTime { get; set; }
    }

    public class CreateOperationDto
    {
        public int OmCode { get; set; }
        public string OmDesc { get; set; } = string.Empty;
        public decimal OmFixRate { get; set; }
    }
}
