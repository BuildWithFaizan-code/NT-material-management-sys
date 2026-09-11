namespace MMSERP.Api.Models
{
    public class ChargesMasterDto
    {
        public int ChgId { get; set; }
        public string ChgName { get; set; } = string.Empty;
        public decimal Disc { get; set; }
        public decimal Amount { get; set; }
        public string AddLess { get; set; } = "+";
        public short IIND { get; set; }
        public short IST { get; set; }
        public string Formula { get; set; } = string.Empty;
        public short Loc { get; set; }
        public short Imp { get; set; }
        public int Priority { get; set; }
        public short ChgPO { get; set; }
        public short ChgGRN { get; set; }
        public short ChgWO { get; set; }
        public decimal Rt { get; set; }
    }
}
