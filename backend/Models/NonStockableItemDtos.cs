namespace MMSERP.Api.Models
{
    public class NonStockableItemDto
    {
        public string ICode { get; set; } = string.Empty;
        public string IName1 { get; set; } = string.Empty;
        public decimal Rate { get; set; }
        public int UnitCode { get; set; }
        public string UnitName { get; set; } = string.Empty;
        public string SacCode { get; set; } = string.Empty;
        public int TaxCode { get; set; }
        public string TaxName { get; set; } = string.Empty;
    }

    public class UnassignedItemDto
    {
        public string ICode { get; set; } = string.Empty;
        public string IName1 { get; set; } = string.Empty;
        public decimal Rate { get; set; }
        public string UnitCode { get; set; } = string.Empty;
        public string SacCode { get; set; } = string.Empty;
        public string TaxCode { get; set; } = string.Empty;
    }

    public class SaveNonStockableItemDto
    {
        public string ICode { get; set; } = string.Empty;
        public string IName1 { get; set; } = string.Empty;
        public decimal Rate { get; set; }
        public int UnitCode { get; set; }
        public string SacCode { get; set; } = string.Empty;
        public int TaxCode { get; set; }
    }

    public class UnitOptionDto
    {
        public int UnitCode { get; set; }
        public string UnitName { get; set; } = string.Empty;
    }

    public class TaxSlabOptionDto
    {
        public int TaxCode { get; set; }
        public string TaxName { get; set; } = string.Empty;
    }

    public class NonStockableDropdownsDto
    {
        public List<UnitOptionDto> Units { get; set; } = new();
        public List<TaxSlabOptionDto> TaxSlabs { get; set; } = new();
    }
}
