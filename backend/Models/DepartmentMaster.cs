namespace MMSERP.Api.Models
{
    public class DepartmentMasterDto
    {
        public int LabCode { get; set; }
        public string LabName { get; set; } = string.Empty;
        public string? LabSeries { get; set; }
        public string LabStatus { get; set; } = "YES";
        public string? LabAdd { get; set; }
        public int? LabPCode { get; set; }
        public string? PName { get; set; }
    }

    public class PartyAccountDto
    {
        public int PCode { get; set; }
        public string PName { get; set; } = string.Empty;
    }

    public class PartyAccountLookupDto
    {
        public int PartyCode { get; set; }
        public int PCode { get => PartyCode; set => PartyCode = value; }
        public string AccountName { get; set; } = string.Empty;
        public string Account { get => AccountName; set => AccountName = value; }
        public string MobileNo { get; set; } = string.Empty;
        public string Gstin { get; set; } = string.Empty;
        public string StateCode { get; set; } = string.Empty;
        public string Address { get; set; } = string.Empty;
    }

    public class CreateDepartmentDto
    {
        public int LabCode { get; set; }
        public string LabName { get; set; } = string.Empty;
        public string? LabSeries { get; set; }
        public string LabStatus { get; set; } = "YES";
        public string? LabAdd { get; set; }
        public int? LabPCode { get; set; }
    }
}
