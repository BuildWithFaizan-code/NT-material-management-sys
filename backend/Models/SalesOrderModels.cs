using System;
using System.Collections.Generic;

namespace MMSERP.Api.Models
{
    // ============================================================================
    // SALES ORDER MASTER DTO
    // ============================================================================
    public class SalesOrderHeaderDto
    {
        public string SoNo { get; set; } = string.Empty;
        public DateTime SoDate { get; set; }
        public int PCode { get; set; }
        public string PartyName { get; set; } = string.Empty;
        public string Mobile { get; set; } = string.Empty;
        public string Gstin { get; set; } = string.Empty;
        public string StateCode { get; set; } = string.Empty;
        public string Address { get; set; } = string.Empty;
        public int DeptCode { get; set; }
        public string DeptName { get; set; } = string.Empty;
        public string SoMode { get; set; } = "Direct";
        public short TotItm { get; set; }
        public double TotQty { get; set; }
        public double TotDisc { get; set; }
        public double TotAmt { get; set; }
        public double Adv { get; set; }
        public double PfChg { get; set; }
        public double Excise { get; set; }
        public double Freight { get; set; }
        public double Others { get; set; }
        public double NetAmt { get; set; }
        public string Remark { get; set; } = string.Empty;
        public bool Approved { get; set; }
        public DateTime? AppDate { get; set; }
        public bool IsRec { get; set; }
        public DateTime? RecDate { get; set; }
        public bool IsImp { get; set; }
        public string Curr { get; set; } = "INR";
        public bool CloseSo { get; set; }
        public string SuppRef { get; set; } = string.Empty;
        public double SoCrDays { get; set; }
        public string SomLoc { get; set; } = "LWHL26_SQL";
        public DateTime? SomEDate { get; set; }
        public string SomUsrName { get; set; } = string.Empty;
        public string SomEMode { get; set; } = string.Empty;
        public double SomDelDays { get; set; } = 6;
        public short SomCapMode { get; set; }
        public string CapModeName { get; set; } = string.Empty;
        public int CostCd { get; set; }
        public string CostCenterName { get; set; } = string.Empty;
        public int SpCd { get; set; }
        public string SalesPersonName { get; set; } = string.Empty;
        public bool SomIsFreight { get; set; }

        public List<SalesOrderItemDto> Items { get; set; } = new();
        public List<SalesOrderChargeDto> Charges { get; set; } = new();
        public List<SalesOrderConditionDto> Conditions { get; set; } = new();
    }

    // ============================================================================
    // SALES ORDER DETAIL LINE ITEM DTO
    // ============================================================================
    public class SalesOrderItemDto
    {
        public int SId { get; set; }
        public string SoNo { get; set; } = string.Empty;
        public int SrNo { get; set; }
        public string IndCode { get; set; } = "None";
        public string QuoCode { get; set; } = "None";
        public string ICode { get; set; } = string.Empty;
        public string ItemName { get; set; } = string.Empty;
        public short Uom { get; set; }
        public string UnitName { get; set; } = string.Empty;
        public double Qty { get; set; }
        public double AccQty { get; set; }
        public double Rate { get; set; }
        public double Disc { get; set; }
        public double Amount { get; set; }
        public bool IsAppro { get; set; }
        public bool IsRec { get; set; }
        public bool IsReject { get; set; }
        public bool IsHold { get; set; }
        public short KhCode { get; set; }
        public string DivisionName { get; set; } = string.Empty;
        public bool IsGe { get; set; }
        public string GeNo { get; set; } = string.Empty;
        public double ExRate { get; set; }
        public double ExAmt { get; set; }
        public double Freight { get; set; }
        public bool CloseSo { get; set; }
        public string MrgNo { get; set; } = string.Empty;
        public DateTime? SoAppDt { get; set; }
        public int DepCode { get; set; }
        public string DeptName { get; set; } = string.Empty;
        public string Specification { get; set; } = string.Empty;
        public bool SodIsFreight { get; set; }
    }

    // ============================================================================
    // SALES ORDER CHARGES & CONDITIONS
    // ============================================================================
    public class SalesOrderChargeDto
    {
        public int Id { get; set; }
        public short ChgId { get; set; }
        public string ChgName { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
        public double Per { get; set; }
        public double Amt { get; set; }
        public string Mode { get; set; } = "QUOTATION";
        public short AddLess { get; set; } = 1; // 1 = Add, -1 = Less
        public string Exp { get; set; } = string.Empty;
        public string Remark { get; set; } = string.Empty;
    }

    public class SalesOrderConditionDto
    {
        public int ConId { get; set; }
        public short ConNo { get; set; }
        public string Code { get; set; } = string.Empty;
        public string ConditionText { get; set; } = string.Empty;
    }

    // ============================================================================
    // LOOKUP MODELS
    // ============================================================================
    public class CustomerLookupDto
    {
        public int PCode { get; set; }
        public string PName { get; set; } = string.Empty;
        public string Mobile { get; set; } = string.Empty;
        public string Gstin { get; set; } = string.Empty;
        public string StateCode { get; set; } = string.Empty;
        public string Address { get; set; } = string.Empty;
        public int CreditDays { get; set; }
    }

    public class SalesOrderItemLookupDto
    {
        public string ICode { get; set; } = string.Empty;
        public string ItName { get; set; } = string.Empty;
        public short UnitCode { get; set; }
        public string UnitName { get; set; } = string.Empty;
        public string Hsn { get; set; } = string.Empty;
    }

    public class SalesPersonLookupDto
    {
        public int SpmCode { get; set; }
        public string SpmName { get; set; } = string.Empty;
    }

    public class CostCenterLookupDto
    {
        public short KhCode { get; set; }
        public string KhName { get; set; } = string.Empty;
    }

    public class SalesOrderLookupsDto
    {
        public string NextSoNo { get; set; } = string.Empty;
        public List<string> Currencies { get; set; } = new();
        public List<LocationLookupDto> CapModes { get; set; } = new();
        public List<CostCenterLookupDto> CostCenters { get; set; } = new();
        public List<SalesPersonLookupDto> SalesPersons { get; set; } = new();
        public List<SalesOrderChargeDto> DefaultCharges { get; set; } = new();
        public List<SalesOrderConditionDto> DefaultConditions { get; set; } = new();
        public string CompanyStateCode { get; set; } = "24";
    }

    // ============================================================================
    // REQUEST / RESPONSE PAYLOADS
    // ============================================================================
    public class SalesOrderFilterRequest
    {
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
        public int? CostCd { get; set; }
        public int? PCode { get; set; }
        public int? SpCd { get; set; }
        public string? SearchQuery { get; set; }
        public int Page { get; set; } = 1;
        public int PageSize { get; set; } = 50;
    }

    public class SalesOrderSaveRequest
    {
        public bool IsEdit { get; set; } = false;
        public string? SoNo { get; set; } // null or empty for new order
        public DateTime SoDate { get; set; } = DateTime.Today;
        public int PCode { get; set; }
        public int DeptCode { get; set; }
        public string SoMode { get; set; } = "Direct";
        public double TotQty { get; set; }
        public double TotDisc { get; set; }
        public double TotAmt { get; set; }
        public double PfChg { get; set; }
        public double Freight { get; set; }
        public double Others { get; set; }
        public double NetAmt { get; set; }
        public string Remark { get; set; } = string.Empty;
        public bool IsImp { get; set; }
        public string Curr { get; set; } = "INR";
        public string SuppRef { get; set; } = string.Empty;
        public DateTime? RecDate { get; set; }
        public double SoCrDays { get; set; }
        public double SomDelDays { get; set; } = 6;
        public short SomCapMode { get; set; }
        public int CostCd { get; set; }
        public int SpCd { get; set; }
        public bool SomIsFreight { get; set; }

        public List<SalesOrderItemDto> Items { get; set; } = new();
        public List<SalesOrderChargeDto> Charges { get; set; } = new();
        public List<SalesOrderConditionDto> Conditions { get; set; } = new();
    }

    public class SalesOrderPagedResult<T>
    {
        public List<T> Items { get; set; } = new();
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
    }
}
