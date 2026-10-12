using System;
using System.Collections.Generic;

namespace MMSERP.Api.Models
{
    public class PoApprovalDepartmentDto
    {
        public int LabCode { get; set; }
        public string LabName { get; set; } = string.Empty;
    }

    public class PoApprovalPlantDto
    {
        public int StrCode { get; set; }
        public string StrName { get; set; } = string.Empty;
    }

    public class PoApprovalSupplierDto
    {
        public int PCode { get; set; }
        public string PName { get; set; } = string.Empty;
    }

    public class PoApprovalLookupsDto
    {
        public List<PoApprovalDepartmentDto> Departments { get; set; } = new();
        public List<PoApprovalPlantDto> Plants { get; set; } = new();
        public List<PoApprovalSupplierDto> Suppliers { get; set; } = new();
    }

    public class PoApprovalRecordDto
    {
        public string PurOrdNo { get; set; } = string.Empty;
        public DateTime PoDate { get; set; }
        public string RefNo { get; set; } = string.Empty;
        public DateTime? RefDate { get; set; }
        public string Department { get; set; } = string.Empty;
        public int DeptCode { get; set; }
        public string Plant { get; set; } = string.Empty;
        public int PlantCode { get; set; }
        public string PartyName { get; set; } = string.Empty;
        public int PartyCode { get; set; }
        public string ItCode { get; set; } = string.Empty;
        public string ItemName { get; set; } = string.Empty;
        public string Shade { get; set; } = string.Empty;
        public decimal PoQty { get; set; }
        public decimal InwardQty { get; set; }
        public decimal BalanceQty { get; set; }
        public decimal Rate { get; set; }
        public decimal Amount { get; set; }
        public decimal Freight { get; set; }
        public int PId { get; set; }
        public int IsAppro { get; set; }
        public int IsReject { get; set; }
        public int IsHold { get; set; }
        public int ClosePo { get; set; }
        public string IndCode { get; set; } = string.Empty;
        public string PodClosRem { get; set; } = string.Empty;
        public string? ProcessDo { get; set; }

        public string Status
        {
            get
            {
                if (ClosePo != 0) return "Closed";
                if (IsReject != 0) return "Rejected";
                if (IsHold != 0) return "Hold";
                if (IsAppro != 0) return "Approved";
                return "Pending";
            }
        }
    }

    public class PoApprovalFilterQuery
    {
        /// <summary>
        /// PENDING (default unapproved), APPROVED, REJECTED, HOLD, CLOSE, UNCLOSE
        /// </summary>
        public string ViewMode { get; set; } = "PENDING";
        public int? DeptCode { get; set; }
        public int? PlantCode { get; set; }
        public int? PartyCode { get; set; }
        public string? PoNo { get; set; }
        public string? ItemSearch { get; set; }
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
    }

    public class PoApprovalActionItem
    {
        public string PoNo { get; set; } = string.Empty;
        public int PId { get; set; }
        public string? DepartmentName { get; set; }
    }

    public class PoApprovalActionRequest
    {
        /// <summary>
        /// Approve, Reject, Hold, Close, UnClose
        /// </summary>
        public string ActionType { get; set; } = "Approve";
        public DateTime ApprovalDate { get; set; } = DateTime.Today;
        public string? Remark { get; set; }
        public List<PoApprovalActionItem> Items { get; set; } = new();
    }
}
