using System;
using System.Collections.Generic;

namespace MMSERP.Api.Models
{
    // ============================================================================
    // PURCHASE ORDER DTO CONTRACTS (STRICT LEGACY COMPLIANCE)
    // ============================================================================

    public record PurchaseOrderHeaderDto
    {
        public string PoNo { get; set; } = string.Empty;
        public DateTime PoDate { get; set; }
        public int PCode { get; set; }
        public string PartyName { get; set; } = string.Empty;
        public string Gstin { get; set; } = string.Empty;
        public string StateCode { get; set; } = string.Empty;
        public string Address { get; set; } = string.Empty;
        public int PoDelCd { get; set; }
        public string DelPartyName { get; set; } = string.Empty;
        public int PStrCode { get; set; }
        public string StoreName { get; set; } = string.Empty;
        public int DeptCode { get; set; }
        public string DeptName { get; set; } = string.Empty;
        public string PoMode { get; set; } = "Direct";
        public short TotItm { get; set; }
        public double TotQty { get; set; }
        public double TotDisc { get; set; }
        public double TotAmt { get; set; }
        public double PfChg { get; set; }
        public double Excise { get; set; }
        public double LstChst { get; set; }
        public double Freight { get; set; }
        public double Insurance { get; set; }
        public double Others { get; set; }
        public double NetAmt { get; set; }
        public string DTerms { get; set; } = string.Empty;
        public string PTerms { get; set; } = string.Empty;
        public string DispIns { get; set; } = string.Empty;
        public string SpNote { get; set; } = string.Empty;
        public string Remark { get; set; } = string.Empty;
        public bool Approved { get; set; }
        public DateTime? AppDate { get; set; }
        public bool IsRec { get; set; }
        public DateTime? RecDate { get; set; }
        public bool IsImp { get; set; }
        public string Curr { get; set; } = string.Empty;
        public string Words { get; set; } = string.Empty;
        public bool ClosePO { get; set; }
        public string SuppRef { get; set; } = string.Empty;
        public short PoCrDays { get; set; }
        public short PomDelDays { get; set; }
        public short PomCapMode { get; set; }
        public string PomUsrName { get; set; } = string.Empty;
        public DateTime? PomEDate { get; set; }
        public double CgPer { get; set; }
        public double CgAmt { get; set; }
        public double SgPer { get; set; }
        public double SgAmt { get; set; }
        public double IgPer { get; set; }
        public double IgAmt { get; set; }
        public int PomBrCode { get; set; }
        public string BrokerName { get; set; } = string.Empty;
        public short PomIsFreight { get; set; }

        public List<PurchaseOrderItemDto> Items { get; set; } = new();
        public List<PurchaseOrderChargeDto> Charges { get; set; } = new();
        public List<PurchaseOrderConditionDto> Conditions { get; set; } = new();
    }

    public record PurchaseOrderItemDto
    {
        public int PId { get; set; }
        public string PoNo { get; set; } = string.Empty;
        public int SrNo { get; set; }
        public string IndCode { get; set; } = "None";
        public string QuoCode { get; set; } = "None";
        public string ICode { get; set; } = string.Empty;
        public string ItemName { get; set; } = string.Empty;
        public string Hsn { get; set; } = string.Empty;
        public int Uom { get; set; }
        public string UnitName { get; set; } = string.Empty;
        public double Qty { get; set; }
        public double AccQty { get; set; }
        public double Rate { get; set; }
        public double Disc { get; set; }
        public double Amount { get; set; }
        public int KhCode { get; set; }
        public string DivisionName { get; set; } = string.Empty;
        public int DepCode { get; set; }
        public string DeptName { get; set; } = string.Empty;
        public string MrgNo { get; set; } = string.Empty;
        public string Shade { get; set; } = string.Empty;
        public string Specification { get; set; } = string.Empty;
        public string PRemark { get; set; } = string.Empty;
        public double Freight { get; set; }
        public short PodIsFreight { get; set; }
        public double CgPer { get; set; }
        public double CgAmt { get; set; }
        public double SgPer { get; set; }
        public double SgAmt { get; set; }
        public double IgPer { get; set; }
        public double IgAmt { get; set; }
        public double NetAmt { get; set; }
        public double PodStock { get; set; }
        public double PodLastRate { get; set; }
        public int PodMakeId { get; set; }
        public string MakerName { get; set; } = string.Empty;
        public int PodConvUom { get; set; }
        public string ConvUnitName { get; set; } = string.Empty;
        public double PodConvQty { get; set; }
        public bool ClosePO { get; set; }
    }

    public record PurchaseOrderChargeDto
    {
        public int Id { get; set; }
        public int ChgId { get; set; }
        public string ChgName { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
        public double Per { get; set; }
        public decimal Amt { get; set; }
        public string Mode { get; set; } = "PURCHASE";
        private short _addLess = 1;
        public object AddLess
        {
            get => _addLess;
            set => _addLess = ChargesMasterLookupDto.ParseAddLess(value);
        }
        public string Exp { get; set; } = string.Empty;
        public string Remark { get; set; } = string.Empty;
    }

    public record PurchaseOrderConditionDto
    {
        public int ConId { get; set; }
        public short ConNo { get; set; }
        public string Code { get; set; } = string.Empty;
        public string ConditionText { get; set; } = string.Empty;
    }

    public record PurchaseOrderSaveRequest
    {
        public string PoNo { get; set; } = string.Empty; // Empty for new, populated for edit
        public DateTime PoDate { get; set; }
        public int PCode { get; set; }
        public int PoDelCd { get; set; }
        public int PStrCode { get; set; }
        public int DeptCode { get; set; }
        public string PoMode { get; set; } = "Direct";
        public string Curr { get; set; } = string.Empty;
        public string Words { get; set; } = string.Empty;
        public string SuppRef { get; set; } = string.Empty;
        public DateTime? RecDate { get; set; }
        public short PoCrDays { get; set; }
        public short PomDelDays { get; set; }
        public short PomCapMode { get; set; }
        public bool IsImp { get; set; }
        public short PomIsFreight { get; set; }
        public int PomBrCode { get; set; }

        public double TotQty { get; set; }
        public double TotDisc { get; set; }
        public double TotAmt { get; set; }
        public double PfChg { get; set; }
        public double Freight { get; set; }
        public double Insurance { get; set; }
        public double Others { get; set; }
        public double NetAmt { get; set; }
        public double CgPer { get; set; }
        public double CgAmt { get; set; }
        public double SgPer { get; set; }
        public double SgAmt { get; set; }
        public double IgPer { get; set; }
        public double IgAmt { get; set; }

        public string DTerms { get; set; } = string.Empty;
        public string PTerms { get; set; } = string.Empty;
        public string DispIns { get; set; } = string.Empty;
        public string SpNote { get; set; } = string.Empty;
        public string Remark { get; set; } = string.Empty;

        public List<PurchaseOrderItemSaveDto> Items { get; set; } = new();
        public List<PurchaseOrderChargeSaveDto> Charges { get; set; } = new();
        public List<PurchaseOrderConditionSaveDto> Conditions { get; set; } = new();
    }

    public record PurchaseOrderItemSaveDto
    {
        public int SrNo { get; set; }
        public string ICode { get; set; } = string.Empty;
        public int Uom { get; set; }
        public double Qty { get; set; }
        public double Rate { get; set; }
        public double Disc { get; set; }
        public double Amount { get; set; }
        public int KhCode { get; set; }
        public int DepCode { get; set; }
        public string MrgNo { get; set; } = string.Empty;
        public string Shade { get; set; } = string.Empty;
        public string Specification { get; set; } = string.Empty;
        public string PRemark { get; set; } = string.Empty;
        public double Freight { get; set; }
        public short PodIsFreight { get; set; }
        public double CgPer { get; set; }
        public double CgAmt { get; set; }
        public double SgPer { get; set; }
        public double SgAmt { get; set; }
        public double IgPer { get; set; }
        public double IgAmt { get; set; }
        public double PodStock { get; set; }
        public double PodLastRate { get; set; }
        public int PodMakeId { get; set; }
        public int PodConvUom { get; set; }
        public double PodConvQty { get; set; }
    }

    public record PurchaseOrderChargeSaveDto
    {
        public int ChgId { get; set; }
        public double Per { get; set; }
        public decimal Amt { get; set; }
        public string Remark { get; set; } = string.Empty;
    }

    public record PurchaseOrderConditionSaveDto
    {
        public short ConNo { get; set; }
        public string ConditionText { get; set; } = string.Empty;
    }

    public record PurchaseOrderFilterRequest
    {
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
        public int? StrCode { get; set; }
        public int? PCode { get; set; }
        public string? SearchQuery { get; set; }
        public int Page { get; set; } = 1;
        public int PageSize { get; set; } = 50;
    }

    public record PurchaseOrderPagedResult<T>
    {
        public List<T> Items { get; set; } = new();
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
    }

    // ============================================================================
    // SELECTION & LOOKUP DTOS (MATCHING TRACE QUERIES)
    // ============================================================================

    public record SupplierLookupDto
    {
        public int PCode { get; set; }
        public string PName { get; set; } = string.Empty;
        public string Gstin { get; set; } = string.Empty;
        public string StateCode { get; set; } = string.Empty;
        public string Address { get; set; } = string.Empty;
        public int BrkCode { get; set; }
        public string Agent { get; set; } = string.Empty;
        public string TypeOfRegistrant { get; set; } = string.Empty;
        public int CreditDays { get; set; }
    }

    public record ItemLookupDto
    {
        public string ICode { get; set; } = string.Empty;
        public string ItName { get; set; } = string.Empty;
        public int UnitCode { get; set; }
        public string UnitName { get; set; } = string.Empty;
        public double Stock { get; set; }
        public string CatName { get; set; } = string.Empty;
        public int CatCode { get; set; }
        public string Hsn { get; set; } = string.Empty;
        public double TaxSlab { get; set; }
        public string Shade { get; set; } = string.Empty;
        public int SecUcode { get; set; }
        public string SecUnit { get; set; } = string.Empty;
        public double Conversion { get; set; }
        public string Design { get; set; } = string.Empty;
        public string Style { get; set; } = string.Empty;
        public string Size { get; set; } = string.Empty;
        public bool SizeReq { get; set; }
        public bool GradeReq { get; set; }
    }

    public record ItemMergeLookupDto
    {
        public string MergeLotNo { get; set; } = string.Empty;
        public string Shade { get; set; } = string.Empty;
        public string Maker { get; set; } = string.Empty;
        public int MakerCode { get; set; }
    }

    public record ShadeLookupDto
    {
        public string PshadeCode { get; set; } = string.Empty;
    }

    public record StoreLookupDto
    {
        public int StrCode { get; set; }
        public string StrName { get; set; } = string.Empty;
    }

    public record CapModeLookupDto
    {
        public int LocCode { get; set; }
        public string Location { get; set; } = string.Empty;
    }

    public record DepartmentLookupDto
    {
        public int LabCode { get; set; }
        public string LabName { get; set; } = string.Empty;
    }

    public record DivisionLookupDto
    {
        public int KhCode { get; set; }
        public string KhName { get; set; } = string.Empty;
    }

    public record ChargesMasterLookupDto
    {
        public int Priority { get; set; }
        public int ChgId { get; set; }
        public string ChgName { get; set; } = string.Empty;
        public double Disc { get; set; }
        private short _addLess = 1;
        public object AddLess
        {
            get => _addLess;
            set => _addLess = ParseAddLess(value);
        }
        public string Exp { get; set; } = string.Empty;

        public static short ParseAddLess(object? val)
        {
            if (val == null || val is DBNull) return 1;
            if (val is short s) return s;
            if (val is int i) return (short)i;
            if (val is long l) return (short)l;
            if (val is byte b) return (short)b;
            if (val is char c) return c == '-' ? (short)-1 : (short)1;
            if (val is System.Text.Json.JsonElement je)
            {
                if (je.ValueKind == System.Text.Json.JsonValueKind.Number && je.TryGetInt16(out var num)) return num;
                if (je.ValueKind == System.Text.Json.JsonValueKind.String)
                {
                    var strVal = je.GetString()?.Trim();
                    if (strVal == "-" || strVal == "-1") return -1;
                    return 1;
                }
            }
            var sVal = val.ToString()?.Trim();
            if (sVal == "-" || sVal == "-1") return -1;
            if (short.TryParse(sVal, out var parsed)) return parsed;
            return 1;
        }
    }

    public record PurchaseOrderLookupsDto
    {
        public string NextPoNo { get; set; } = string.Empty;
        public string CompanyStateCode { get; set; } = "27";
        public List<StoreLookupDto> Stores { get; set; } = new();
        public List<string> Currencies { get; set; } = new();
        public List<CapModeLookupDto> CapModes { get; set; } = new();
        public List<DepartmentLookupDto> Departments { get; set; } = new();
        public List<DivisionLookupDto> Divisions { get; set; } = new();
        public List<ChargesMasterLookupDto> DefaultCharges { get; set; } = new();
        public List<string> DeliveryTermsSuggestions { get; set; } = new();
        public List<string> PaymentTermsSuggestions { get; set; } = new();
        public List<string> DispatchInstructionsSuggestions { get; set; } = new();
        public List<string> SpecialNotesSuggestions { get; set; } = new();
        public List<string> RemarksSuggestions { get; set; } = new();
    }
}
