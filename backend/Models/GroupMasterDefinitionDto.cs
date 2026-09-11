using System;

namespace MMSERP.Api.Models
{
    public class GroupMasterDefinitionDto
    {
        public string IsmMsCode { get; set; } = string.Empty;
        public string IsmMCode { get; set; } = string.Empty;
        public string IsmSubCode { get; set; } = string.Empty;
        public string IsmSubCatCode { get; set; } = string.Empty;
        public string? CatName { get; set; }
        public string? CatShort { get; set; }
        public string? WipName { get; set; }
    }

    public class CategoryLookupDto
    {
        public string CatCode { get; set; } = string.Empty;
        public string CatName { get; set; } = string.Empty;
    }

    public class MainGroupLookupDto
    {
        public string WipCode { get; set; } = string.Empty;
        public string WipName { get; set; } = string.Empty;
    }
}
