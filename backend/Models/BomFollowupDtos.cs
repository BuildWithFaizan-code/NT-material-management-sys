using System;
using System.Collections.Generic;

namespace MMSERP.Api.Models
{
    // ============================================================================
    // BILL OF MATERIAL CLOSE / FOLLOW UP DTO CONTRACTS
    // ============================================================================

    public record BomFollowupDepartmentDto
    {
        public int LabCode { get; set; }
        public string LabName { get; set; } = string.Empty;
    }

    public record BomFollowupDivisionDto
    {
        public int KhCode { get; set; }
        public string KhName { get; set; } = string.Empty;
    }

    public record BomFollowupOrderTypeDto
    {
        public string BomType { get; set; } = string.Empty;
    }

    public record BomFollowupRecordDto
    {
        public string BomId { get; set; } = string.Empty;
        public DateTime BomDate { get; set; }
        public int LabCode { get; set; }
        public string Department { get; set; } = string.Empty;
        public int StrCode { get; set; }
        public string Branch { get; set; } = string.Empty;
        public int KhCode { get; set; }
        public string Division { get; set; } = string.Empty;
        public string MaterialName { get; set; } = string.Empty;
        public string MaterialCode { get; set; } = string.Empty;
        public string MergeNo { get; set; } = string.Empty;
        public decimal Qty { get; set; }
        public decimal Stock { get; set; }
        public string Status { get; set; } = "OPEN";
        public DateTime? DtAndTime { get; set; }
        public string User { get; set; } = string.Empty;
        public decimal Rate { get; set; }
        public string Uqc { get; set; } = string.Empty;
        public int Ucode { get; set; }
    }

    public record BomFollowupFilterRequest
    {
        public DateTime? AsOnDate { get; set; }
        public int? DepartmentCode { get; set; }
        public int? DivisionCode { get; set; }
        public string? OrderType { get; set; }
    }

    public record BomFollowupCloseRequest
    {
        public List<string> BomIds { get; set; } = new();
        public DateTime AsOnDate { get; set; } = DateTime.UtcNow;
    }

    public record BomFollowupCloseResult
    {
        public bool Success { get; set; }
        public int ClosedCount { get; set; }
        public string Message { get; set; } = string.Empty;
        public bool IsDateLocked { get; set; }
    }
}
