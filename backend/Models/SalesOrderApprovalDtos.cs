using System;
using System.Collections.Generic;

namespace MMSERP.Api.Models
{
    public class SoApprovalDepartmentDto
    {
        public int LabCode { get; set; }
        public string LabName { get; set; } = string.Empty;
    }

    public class SoApprovalCustomerDto
    {
        public int PCode { get; set; }
        public string PName { get; set; } = string.Empty;
    }

    public class SoApprovalItemLookupDto
    {
        public string ItCode { get; set; } = string.Empty;
        public string ItemName { get; set; } = string.Empty;
    }

    public class SoApprovalLookupsDto
    {
        public List<SoApprovalDepartmentDto> Departments { get; set; } = new();
        public List<SoApprovalCustomerDto> Customers { get; set; } = new();
        public List<string> OrderNumbers { get; set; } = new();
        public List<SoApprovalItemLookupDto> Items { get; set; } = new();
    }

    public class SoApprovalRecordDto
    {
        public string SalOrdNo { get; set; } = string.Empty;
        public DateTime SoDate { get; set; }
        public string LabName { get; set; } = string.Empty;
        public int DeptCode { get; set; }
        public string PartyName { get; set; } = string.Empty;
        public int PartyCode { get; set; }
        public string ItCode { get; set; } = string.Empty;
        public string ItemName { get; set; } = string.Empty;
        public decimal Qty { get; set; }
        public decimal Rate { get; set; }
        public decimal Amount { get; set; }
        public int SId { get; set; }
        public int IsAppro { get; set; }
        public int IsReject { get; set; }
        public int IsHold { get; set; }
        public int CloseSo { get; set; }
        public int IsRec { get; set; }
        public string IndCode { get; set; } = string.Empty;
        public string SodClosRem { get; set; } = string.Empty;
        public int ProcessDo { get; set; }
        public string CellNo { get; set; } = string.Empty;

        public bool IsApproved => IsAppro != 0;
        public bool IsRejected => IsReject != 0;
        public bool IsOnHold => IsHold != 0;
        public bool IsClosed => CloseSo != 0;

        public string Status
        {
            get
            {
                if (CloseSo != 0) return "Closed";
                if (IsReject != 0) return "Rejected";
                if (IsHold != 0) return "Hold";
                if (IsAppro != 0) return "Approved";
                return "Pending";
            }
        }
    }

    public class SoApprovalFilterQuery
    {
        public string? ViewMode { get; set; } = "PENDING";
        public int? DeptCode { get; set; }
        public int? PartyCode { get; set; }
        public string? SoNo { get; set; }
        public string? ItemSearch { get; set; }
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
    }

    public class SoApprovalActionItem
    {
        public string SoNo { get; set; } = string.Empty;
        public int SId { get; set; }
        public string? ItemCode { get; set; }
        public string? DepartmentName { get; set; }
    }

    public class SoApprovalActionRequest
    {
        public string ActionType { get; set; } = "Approve";
        public DateTime ApprovalDate { get; set; } = DateTime.UtcNow;
        public string? Remark { get; set; }
        public List<SoApprovalActionItem> Items { get; set; } = new();
    }
}
