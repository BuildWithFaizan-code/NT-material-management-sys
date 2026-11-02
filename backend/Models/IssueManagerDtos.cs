using System;
using System.Collections.Generic;

namespace MMSERP.Api.Models
{
    public class IssueManagerLookupsDto
    {
        public List<StockTransferLookupItemDto> Departments { get; set; } = new();
        public List<StockTransferLookupItemDto> Stores { get; set; } = new();
        public List<StockTransferLookupItemDto> Divisions { get; set; } = new();
        public List<string> Machines { get; set; } = new();
        public List<string> IssueModes { get; set; } = new();
        public List<string> IssueSources { get; set; } = new();
    }

    public class IssueManagerLineInputDto
    {
        public int SrNo { get; set; }
        public string ItemCode { get; set; } = string.Empty;
        public string ItemName { get; set; } = string.Empty;
        public int Uom { get; set; }
        public string UnitName { get; set; } = string.Empty;
        public string MrgNo { get; set; } = string.Empty;
        public string Grade { get; set; } = string.Empty;
        public string Shade { get; set; } = string.Empty;
        public string Maker { get; set; } = string.Empty;
        public double Rate { get; set; }
        public double Stock { get; set; }
        public double IssPcs { get; set; }
        public double IssueQty { get; set; }
        public string Remark { get; set; } = string.Empty;
    }

    public class IssueManagerCreateRequestDto
    {
        public DateTime IssueDate { get; set; }
        public string IssueMode { get; set; } = "To Department";
        public string IssueSource { get; set; } = "Direct";
        public int SourceDeptCode { get; set; }
        public string SourceDeptName { get; set; } = string.Empty;
        public int SourceStoreId { get; set; }
        public int SourceDivId { get; set; }
        public string? MachineNo { get; set; }
        public string? Spindal { get; set; }
        public int SlipNo { get; set; }
        public string? JobCard { get; set; }
        public string? VehicleNo { get; set; }
        public string? EwayBillNo { get; set; }
        public string? Remark { get; set; }
        public List<IssueManagerLineInputDto> Lines { get; set; } = new();
    }

    public class IssueManagerGridRecordDto
    {
        public string IssueCode { get; set; } = string.Empty;
        public DateTime IssueDate { get; set; }
        public string IssueMode { get; set; } = string.Empty;
        public string IssueSource { get; set; } = string.Empty;
        public int SourceDeptCode { get; set; }
        public string SourceDeptName { get; set; } = string.Empty;
        public int SourceStoreId { get; set; }
        public string SourceStoreName { get; set; } = string.Empty;
        public int SourceDivId { get; set; }
        public string MachineNo { get; set; } = string.Empty;
        public string Spindal { get; set; } = string.Empty;
        public int SlipNo { get; set; }
        public double TotQty { get; set; }
        public int TotItm { get; set; }
        public double TotPcs { get; set; }
        public string Remark { get; set; } = string.Empty;
        public string CreatedBy { get; set; } = string.Empty;
        public DateTime? CreatedDate { get; set; }
    }

    public class IssueManagerPagedListDto
    {
        public List<IssueManagerGridRecordDto> Records { get; set; } = new();
        public int TotalCount { get; set; }
    }

    public class IssueManagerDetailDto
    {
        public IssueManagerGridRecordDto Header { get; set; } = new();
        public List<IssueManagerLineInputDto> Lines { get; set; } = new();
    }

    public class IssueManagerSaveResultDto
    {
        public string IssueCode { get; set; } = string.Empty;
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
    }
}
