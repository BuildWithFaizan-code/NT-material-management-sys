using System;
using System.Collections.Generic;

namespace MMSERP.Api.Models
{
    // =========================================================================
    // LOOKUP DTOS
    // =========================================================================
    public class IndentDepartmentLookupDto
    {
        public short LabCode { get; set; }
        public string LabName { get; set; } = string.Empty;
    }

    public class IndentStoreLookupDto
    {
        public short StrCode { get; set; }
        public string StrName { get; set; } = string.Empty;
    }

    public class IndentCapModeLookupDto
    {
        public int LocCode { get; set; }
        public string Location { get; set; } = string.Empty;
    }

    public class IndentCostCenterLookupDto
    {
        public int KhCode { get; set; }
        public string KhName { get; set; } = string.Empty;
    }

    public class IndentItemLookupDto
    {
        public string ICode { get; set; } = string.Empty;
        public string ItName { get; set; } = string.Empty;
        public int UnitCode { get; set; }
        public string UnitName { get; set; } = string.Empty;
        public decimal Stk { get; set; }
        public decimal MinQty { get; set; }
        public decimal MaxQty { get; set; }
        public decimal OrderOn { get; set; }
        public string ReqCode { get; set; } = string.Empty;
    }

    public class IndentLookupsDto
    {
        public string NextIndNo { get; set; } = string.Empty;
        public List<IndentDepartmentLookupDto> Departments { get; set; } = new();
        public List<IndentStoreLookupDto> Stores { get; set; } = new();
        public List<IndentCapModeLookupDto> CapModes { get; set; } = new();
        public List<string> Priorities { get; set; } = new() { "Normal", "High", "Urgent" };
        public List<string> Sources { get; set; } = new() { "Manual" };
    }

    // =========================================================================
    // LINE ITEM & HEADER DTOS
    // =========================================================================
    public class IndentDetailDto
    {
        public string IndCode { get; set; } = string.Empty;
        public int Srno { get; set; }
        public string ReqNo { get; set; } = "None";
        public string Code { get; set; } = string.Empty;
        public string ItemName { get; set; } = string.Empty;
        public int Uom { get; set; }
        public string UomName { get; set; } = string.Empty;
        public double Qty { get; set; }
        public double Rate { get; set; }
        public double TotalValue { get; set; }
        public int KhCode { get; set; }
        public string CostCenterName { get; set; } = string.Empty;
        public short DeptCode { get; set; }
        public string DeptName { get; set; } = string.Empty;
        public DateTime ReqDate { get; set; }
        public bool IsAppro { get; set; }
    }

    public class IndentHeaderDto
    {
        public string IndCode { get; set; } = string.Empty;
        public DateTime IndDate { get; set; }
        public short DeptCode { get; set; }
        public string DeptName { get; set; } = string.Empty;
        public short StoreCode { get; set; }
        public string StoreName { get; set; } = string.Empty;
        public string Priority { get; set; } = "Normal";
        public string Source { get; set; } = "Manual";
        public short TotItem { get; set; }
        public double TotQty { get; set; }
        public double TotAmt { get; set; }
        public string Remark { get; set; } = string.Empty;
        public bool IsAppro { get; set; }
        public DateTime? AppDate { get; set; }
        public string IndUsrName { get; set; } = string.Empty;
        public string IndEMode { get; set; } = "New";
        public short IndCapMode { get; set; }
        public string CapModeName { get; set; } = string.Empty;
        public int TypeId { get; set; }
        public List<IndentDetailDto> Items { get; set; } = new();
    }

    // =========================================================================
    // REQUEST & FILTER DTOS
    // =========================================================================
    public class IndentFilterRequest
    {
        public string? Search { get; set; }
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
        public int Page { get; set; } = 1;
        public int PageSize { get; set; } = 25;
        public string? SortBy { get; set; }
        public bool SortDesc { get; set; } = true;
    }

    public class IndentPagedResult<T>
    {
        public List<T> Items { get; set; } = new();
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
        public int TotalPages => PageSize > 0 ? (int)Math.Ceiling((double)TotalCount / PageSize) : 0;
    }

    public class IndentLineItemSaveRequest
    {
        public int Srno { get; set; }
        public string ReqNo { get; set; } = "None";
        public string Code { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public int Uom { get; set; }
        public double Qty { get; set; }
        public double Rate { get; set; }
        public double TotalValue { get; set; }
        public int KhCode { get; set; }
        public short DeptCode { get; set; }
        public DateTime ReqDate { get; set; }
    }

    public class IndentSaveRequest
    {
        public DateTime IndDate { get; set; }
        public short DeptCode { get; set; }
        public short StoreCode { get; set; }
        public string Priority { get; set; } = "Normal";
        public string Source { get; set; } = "Manual";
        public string Remark { get; set; } = string.Empty;
        public short CapMode { get; set; } = 3;
        public List<IndentLineItemSaveRequest> Items { get; set; } = new();
    }
}
