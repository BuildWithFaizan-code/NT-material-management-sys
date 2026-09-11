namespace MMSERP.Api.Models
{
    public class SubDepartmentMasterDto
    {
        public int SdmCode { get; set; }
        public string SdmName { get; set; } = string.Empty;
    }

    public class CreateSubDepartmentDto
    {
        public int SdmCode { get; set; }
        public string SdmName { get; set; } = string.Empty;
    }
}
