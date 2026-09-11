using System.ComponentModel.DataAnnotations;

namespace MMSERP.Api.Models
{
    public class GroupMasterDto
    {
        [Required]
        public string CatCode { get; set; } = string.Empty;

        [Required]
        public string CatName { get; set; } = string.Empty;

        public string CatHsn { get; set; } = string.Empty;
        public string CatTaxSlab { get; set; } = string.Empty;
        public string PalletReq { get; set; } = "No";
        public string SizeReq { get; set; } = "No";
        public string BoxReq { get; set; } = "No";
        public string GradeReq { get; set; } = "No";
        public string GsmReq { get; set; } = "No";
        public decimal CatTol { get; set; } = 0;
        public string CatShort { get; set; } = string.Empty;
        public string PackTypeName { get; set; } = string.Empty;
    }

    public class TaxSlabDto
    {
        public string TaxCode { get; set; } = string.Empty;
        public string TaxName { get; set; } = string.Empty;
    }
}
