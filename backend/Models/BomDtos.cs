using System;
using System.Collections.Generic;

namespace MMSERP.Api.Models
{
    // ============================================================================
    // BILL OF MATERIALS (BOM) DATA TRANSFER OBJECTS (ENTERPRISE ERP STANDARD)
    // ============================================================================

    public record BomHeaderDto
    {
        public string BomId { get; set; } = string.Empty;
        public string BomCode { get; set; } = string.Empty;
        public int DepCode { get; set; }
        public string DepName { get; set; } = string.Empty;
        public int StrCode { get; set; }
        public string StrName { get; set; } = string.Empty;
        public string ICode { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public double Qty { get; set; } = 1.0;
        public int UnitCode { get; set; }
        public string UnitName { get; set; } = string.Empty;
        public string Purpose { get; set; } = "Costing";
        public string Status { get; set; } = "OPEN";
        public string BomType { get; set; } = "JOB"; // 'JOB' or 'REGULAR'
        public DateTime BomDate { get; set; } = DateTime.UtcNow;
        public string BomPo { get; set; } = string.Empty;
        public string BomLoc { get; set; } = "LWHL26_SQL";
        public string BomUsrName { get; set; } = "SYSTEM";
        public string BomEMode { get; set; } = "New";
        public DateTime BomEDate { get; set; } = DateTime.UtcNow;
    }

    public record BomSubItemDto
    {
        public string BomsId { get; set; } = string.Empty;
        public string BomsCode { get; set; } = string.Empty;
        public string BomCode { get; set; } = string.Empty;
        public int ItGroupCd { get; set; } = 0;
        public string ICode { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string MaterialType { get; set; } = "RAW MATERIAL";
        public double Qty { get; set; } = 1.0;
        public int UnitCode { get; set; } = 0;
        public string UnitName { get; set; } = string.Empty;
        public double Sqm { get; set; } = 0.0;
        public double BomCons { get; set; } = 1.0;
        public double BomExtra { get; set; } = 0.0;
        public double BomTolQty { get; set; } = 0.0;
        public double BomTotQty { get; set; } = 1.0;
        public double ConvQty { get; set; } = 1.0;
        public double BomRate { get; set; } = 0.0;
        public string BomRateUnit { get; set; } = string.Empty;
        public double BomAmount { get; set; } = 0.0;
        public string BomRemarks { get; set; } = string.Empty;
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
