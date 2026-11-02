using System;
using System.Collections.Generic;

namespace MMSERP.Api.Models
{
    public class MaterialReturnLookupItemDto
    {
        public string Code { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public int? Id { get; set; }
        public string? Hsn { get; set; }
    }

    public class MaterialReturnOperatorDto
    {
        public string OperCode { get; set; } = string.Empty;
        public string OperName { get; set; } = string.Empty;
        public bool IsEmp { get; set; }
    }

    public class MaterialReturnLookupsDto
    {
        public List<MaterialReturnLookupItemDto> Departments { get; set; } = new();
        public List<MaterialReturnLookupItemDto> Stores { get; set; } = new();
        public List<MaterialReturnLookupItemDto> Divisions { get; set; } = new();
        public List<MaterialReturnLookupItemDto> Parties { get; set; } = new();
        public List<MaterialReturnOperatorDto> Operators { get; set; } = new();
        public List<string> ReturnModes { get; set; } = new();
        public List<string> ReturnSources { get; set; } = new();
        public string DefaultLocation { get; set; } = "HO";
        public string DefaultCostCenter { get; set; } = "DEFAULT";
        public string DefaultAddress { get; set; } = string.Empty;
    }

    public class MaterialReturnCatalogItemDto
    {
        public string ItemCode { get; set; } = string.Empty;
        public string ItemName { get; set; } = string.Empty;
        public string Uom { get; set; } = string.Empty;
        public double BalanceQty { get; set; }
        public double Stock { get; set; }
        public double AvgRate { get; set; }
        public string HsnCode { get; set; } = string.Empty;
        public double Cops { get; set; }
        public string ConvUom { get; set; } = string.Empty;
        public double ConvQty { get; set; }
        public string MrgNo { get; set; } = string.Empty;
        public string MatGrade { get; set; } = string.Empty;
        public string MatShade { get; set; } = string.Empty;
        public string MatMaker { get; set; } = string.Empty;
        public string BinNo { get; set; } = string.Empty;
        public double Cgper { get; set; }
        public double Sgper { get; set; }
        public double Igper { get; set; }
    }

    public class MaterialReturnStockCatalogPagedResultDto
    {
        public List<MaterialReturnCatalogItemDto> Items { get; set; } = new();
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
    }

    public class MaterialReturnLineInputDto
    {
        public int SrNo { get; set; }
        public string ItemCode { get; set; } = string.Empty;
        public string? ItemName { get; set; } = string.Empty;
        public string? Hsn { get; set; } = string.Empty;
        public string? MrgNo { get; set; } = string.Empty;
        public string? Grade { get; set; } = string.Empty;
        public string? Shade { get; set; } = string.Empty;
        public string? Maker { get; set; } = string.Empty;
        public int Uom { get; set; }
        public string? Uqc { get; set; } = string.Empty;
        public string? UnitName { get; set; } = string.Empty;
        public double Qty { get; set; }
        public double Rate { get; set; }
        public double Amount { get; set; }
        public double Amt { get; set; }
        public double Cops { get; set; }
        public double Stock { get; set; }
        public double Cgst { get; set; }
        public double CGPer { get; set; }
        public double CgstAmt { get; set; }
        public double CGAmt { get; set; }
        public double Sgst { get; set; }
        public double SGPer { get; set; }
        public double SgstAmt { get; set; }
        public double SGAmt { get; set; }
        public double Igst { get; set; }
        public double IGPer { get; set; }
        public double IgstAmt { get; set; }
        public double IGAmt { get; set; }
        public double NetAmt { get; set; }
        public string? BinNo { get; set; } = string.Empty;
        public string? ConvUom { get; set; } = string.Empty;
        public double ConvQty { get; set; }
        public string? RcopsType { get; set; } = string.Empty;
        public string? RetRemark { get; set; } = string.Empty;
        public string? Remark { get; set; } = string.Empty;
        public double Cut { get; set; }
    }

    public class MaterialReturnCreateRequestDto
    {
        public string? RetCode { get; set; }
        public DateTime RetDate { get; set; }
        public string RetMode { get; set; } = "From Department";
        public string RetType { get; set; } = "Direct";
        public string? Source { get; set; }
        public string? RetTo { get; set; }
        public string? RetToName { get; set; }
        public int StoreCode { get; set; } = 1;
        public int DivisionId { get; set; } = 1;
        public int OperCode { get; set; }
        public string? OperatorCode { get; set; }
        public string? Location { get; set; } = "HO";
        public string? CostCenter { get; set; } = "DEFAULT";
        public string Currency { get; set; } = "INR";
        public int CreditDays { get; set; } = 0;
        public string? Gstin { get; set; }
        public bool IsGp { get; set; }
        public string? Remark { get; set; } = string.Empty;
        public double TotQty { get; set; }
        public int TotItm { get; set; }
        public List<MaterialReturnLineInputDto> Lines { get; set; } = new();
    }

    public class MaterialReturnGridRecordDto
    {
        public string RetCode { get; set; } = string.Empty;
        public DateTime RetDate { get; set; }
        public string RetMode { get; set; } = string.Empty;
        public string RetType { get; set; } = string.Empty;
        public string? RetTo { get; set; }
        public string RetToName { get; set; } = string.Empty;
        public int StoreCode { get; set; }
        public string StoreName { get; set; } = string.Empty;
        public int DivisionId { get; set; }
        public double TotQty { get; set; }
        public int TotItm { get; set; }
        public double TotAmt { get; set; }
        public double NetTotAmt { get; set; }
        public string Remark { get; set; } = string.Empty;
        public bool IsGp { get; set; }
        public int OperCode { get; set; }
        public string OperatorName { get; set; } = string.Empty;
        public string OperName { get; set; } = string.Empty;
        public string Location { get; set; } = "HO";
        public string CostCenter { get; set; } = "DEFAULT";
        public string Currency { get; set; } = "INR";
        public int CreditDays { get; set; } = 0;
        public string CreatedBy { get; set; } = string.Empty;
        public DateTime? CreatedDate { get; set; }
    }

    public class MaterialReturnPagedListDto
    {
        public List<MaterialReturnGridRecordDto> Records { get; set; } = new();
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
    }

    public class MaterialReturnDetailDto
    {
        public MaterialReturnGridRecordDto Header { get; set; } = new();
        public List<MaterialReturnLineInputDto> Lines { get; set; } = new();
    }

    public class MaterialReturnSaveResultDto
    {
        public string RetCode { get; set; } = string.Empty;
        public string DocNo { get; set; } = string.Empty;
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
    }
}
