using System;
using System.Collections.Generic;

namespace MMSERP.Api.Models
{
    public class IndentApprovalDepartmentDto
    {
        public int LabCode { get; set; }
        public string LabName { get; set; } = string.Empty;
    }

    public class IndentApprovalItemLookupDto
    {
        public string Code { get; set; } = string.Empty;
        public string ItemName { get; set; } = string.Empty;
    }

    public class IndentApprovalLookupsDto
    {
        public List<string> IndentNumbers { get; set; } = new();
        public List<IndentApprovalDepartmentDto> Departments { get; set; } = new();
        public List<IndentApprovalItemLookupDto> Items { get; set; } = new();
    }

    public class IndentApprovalRecordDto
    {
        public bool? IsAppro { get; set; }
        public string IndCode { get; set; } = string.Empty;
        public DateTime IndDate { get; set; }
        public string LabName { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
        public string ItName { get; set; } = string.Empty;
        public double Qty { get; set; }
        public double Rate { get; set; }
        public double TotalValue { get; set; }
        public int InddetCode { get; set; }
        public bool? IsReject { get; set; }
        public bool? IsHold { get; set; }
        public string ReqNo { get; set; } = string.Empty;
        public string? ProcessDo { get; set; }

        public string Status
        {
            get
            {
                if (IsAppro == true) return "APPROVED";
                if (IsReject == true) return "REJECTED";
                if (IsHold == true) return "HOLD";
                return "PENDING";
            }
        }
    }

    public class IndentApprovalItemSelection
    {
        public string IndCode { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
        public int InddetCode { get; set; }
        public string? DepartmentName { get; set; }
    }

    public class IndentApprovalActionRequest
    {
        /// <summary>
        /// Action to execute: "APPROVE", "REJECT", "HOLD", "RESET"
        /// </summary>
        public string Action { get; set; } = "APPROVE";

        /// <summary>
        /// Approval / effective date
        /// </summary>
        public DateTime ApprovalDate { get; set; } = DateTime.UtcNow;

        /// <summary>
        /// Selected row identifiers to update
        /// </summary>
        public List<IndentApprovalItemSelection> Items { get; set; } = new();
    }

    public class IndentApprovalActionResult
    {
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
        public int AffectedCount { get; set; }
    }
}
