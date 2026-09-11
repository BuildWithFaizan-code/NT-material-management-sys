namespace MMSERP.Api.Models
{
    public class OperatorMasterDto
    {
        public int OperCode { get; set; }
        public string OperName { get; set; } = string.Empty;
        public int OperDepCd { get; set; }
        public string? LabName { get; set; }
    }

    public class DepartmentDto
    {
        public int LabCode { get; set; }
        public string LabName { get; set; } = string.Empty;
    }

    public class CreateOperatorDto
    {
        public int OperCode { get; set; }
        public string OperName { get; set; } = string.Empty;
        public int OperDepCd { get; set; }
    }
}
