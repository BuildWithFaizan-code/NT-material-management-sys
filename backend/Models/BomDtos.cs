using System;
using System.Collections.Generic;

namespace MMSERP.Api.Models
{
    // ============================================================================
    // BILL OF MATERIALS (BOM) DATA TRANSFER OBJECTS (ENTERPRISE ERP STANDARD)
    // ============================================================================

    public record BomHeaderDto
    {
        public string BomId { get; init; } = string.Empty;
        public string BomCode { get; init; } = string.Empty;
        public int DepCode { get; init; }
        public string DepName { get; init; } = string.Empty;
        public int StrCode { get; init; }
        public string StrName { get; init; } = string.Empty;
        public string ICode { get; init; } = string.Empty;
        public string Description { get; init; } = string.Empty;
        public double Qty { get; init; } = 1.0;
        public int UnitCode { get; init; }
        public string UnitName { get; init; } = string.Empty;
        public string Purpose { get; init; } = "Costing";
        public string Status { get; init; } = "OPEN";
        public string BomType { get; init; } = "JOB"; // 'JOB' or 'REGULAR'
        public DateTime BomDate { get; init; } = DateTime.UtcNow;
        public string BomPo { get; init; } = string.Empty;
        public string BomLoc { get; init; } = "LWHL26_SQL";
        public string BomUsrName { get; init; } = "ADMIN";
        public string BomEMode { get; init; } = "New";
        public DateTime BomEDate { get; init; } = DateTime.UtcNow;
    }

    public record BomSubItemDto
    {
        public string BomsId { get; init; } = string.Empty;
        public string BomsCode { get; init; } = string.Empty;
        public string BomCode { get; init; } = string.Empty;
        public int ItGroupCd { get; init; } = 0;
        public string ICode { get; init; } = string.Empty;
        public string Description { get; init; } = string.Empty;
        public string MaterialType { get; init; } = "RAW MATERIAL";
        public double Qty { get; init; } = 1.0;
        public int UnitCode { get; init; } = 0;
        public string UnitName { get; init; } = string.Empty;
        public double Sqm { get; init; } = 0.0;
        public double BomCons { get; init; } = 1.0;
        public double BomExtra { get; init; } = 0.0;
        public double BomTolQty { get; init; } = 0.0;
        public double BomTotQty { get; init; } = 1.0;
        public double ConvQty { get; init; } = 1.0;
        public double BomRate { get; init; } = 0.0;
        public string BomRateUnit { get; init; } = string.Empty;
        public double BomAmount { get; init; } = 0.0;
        public string BomRemarks { get; init; } = string.Empty;
    }

    public record BomCompleteRecordDto
    {
        public BomHeaderDto Header { get; init; } = new();
        public List<BomSubItemDto> Items { get; init; } = new();
    }

    public record BomRecordSummaryDto
    {
        public string BomId { get; init; } = string.Empty;
        public string BomCode { get; init; } = string.Empty;
        public int DepCode { get; init; }
        public string DepName { get; init; } = string.Empty;
        public int StrCode { get; init; }
        public string StrName { get; init; } = string.Empty;
        public string ICode { get; init; } = string.Empty;
        public string Description { get; init; } = string.Empty;
        public double Qty { get; init; } = 1.0;
        public int UnitCode { get; init; }
        public string UnitName { get; init; } = string.Empty;
        public string Status { get; init; } = "OPEN";
        public string BomType { get; init; } = "JOB";
        public DateTime BomDate { get; init; } = DateTime.UtcNow;
        public string BomPo { get; init; } = string.Empty;
        public int SubItemCount { get; init; } = 0;
        public double TotalConsumption { get; init; } = 0.0;
        public double TotalNetQty { get; init; } = 0.0;
    }

    public record FinishedGoodLookupDto
    {
        public string ICode { get; init; } = string.Empty;
        public string ItName { get; init; } = string.Empty;
        public int UnitCode { get; init; }
        public string UnitName { get; init; } = string.Empty;
        public int CatCode { get; init; }
        public string CatName { get; init; } = string.Empty;
        public string SkuCross { get; init; } = "J";
        public string Status { get; init; } = "OPEN";
    }

    public record ComponentLookupDto
    {
        public string ICode { get; init; } = string.Empty;
        public string ItName { get; init; } = string.Empty;
        public int UnitCode { get; init; }
        public string UnitName { get; init; } = string.Empty;
        public int CatCode { get; init; }
        public string CatName { get; init; } = string.Empty;
        public string MaterialType { get; init; } = "RAW MATERIAL";
        public double ConvQty { get; init; } = 1.0;
        public int SecUcode { get; init; }
        public string SecUnit { get; init; } = string.Empty;
        public string PrintCode { get; init; } = string.Empty;
    }

    public record BomStoreLookupDto
    {
        public int StrCode { get; init; }
        public string StrName { get; init; } = string.Empty;
    }

    public record BomDepartmentLookupDto
    {
        public int LabCode { get; init; }
        public string LabName { get; init; } = string.Empty;
    }

    public record BomUnitLookupDto
    {
        public int UnitCode { get; init; }
        public string UnitName { get; init; } = string.Empty;
    }
}
