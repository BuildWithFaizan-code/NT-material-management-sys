using System;
using System.Collections.Generic;

namespace MMSERP.Api.Models
{
    public class StockTransferLookupItemDto
    {
        public int Id { get; set; }
        public string Code { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
    }

    public class StockTransferLookupsDto
    {
        public List<StockTransferLookupItemDto> Departments { get; set; } = new();
        public List<StockTransferLookupItemDto> Stores { get; set; } = new();
        public List<StockTransferLookupItemDto> Divisions { get; set; } = new();
        public List<StockTransferLookupItemDto> Plants { get; set; } = new();
        public List<string> IssueModes { get; set; } = new();
        public string NextDocNo { get; set; } = string.Empty;
    }

    public class StockCatalogItemDto
    {
        public string ItemCode { get; set; } = string.Empty;
        public string ItemName { get; set; } = string.Empty;
        public string MrgNo { get; set; } = string.Empty;
        public string Grade { get; set; } = string.Empty;
        public string Shade { get; set; } = string.Empty;
        public string Maker { get; set; } = string.Empty;
        public int UnitCode { get; set; }
        public string UnitName { get; set; } = string.Empty;
        public double Pcs { get; set; }
        public double Rate { get; set; }
        public double Stock { get; set; }
        public string IBlock { get; set; } = string.Empty;
        public string SimBin { get; set; } = string.Empty;
        public double Meter { get; set; }
        public string MatType { get; set; } = string.Empty;
    }

    public class StockCatalogPagedResultDto
    {
        public List<StockCatalogItemDto> Items { get; set; } = new();
        public int TotalCount { get; set; }
    }

    public class PendingRequisitionItemDto
    {
        public string ReqCode { get; set; } = string.Empty;
        public DateTime ReqDate { get; set; }
        public string ItemCode { get; set; } = string.Empty;
        public string ItemName { get; set; } = string.Empty;
        public int Uom { get; set; }
        public string UnitName { get; set; } = string.Empty;
        public double ReqQty { get; set; }
        public double BalQty { get; set; }
        public double Rate { get; set; }
        public string MrgNo { get; set; } = string.Empty;
        public string Grade { get; set; } = string.Empty;
        public string Shade { get; set; } = string.Empty;
    }

    public class StockTransferLineInputDto
    {
        public int SrNo { get; set; }
        public string ReqCode { get; set; } = "None";
        public double ReqQty { get; set; }
        public string ItemCode { get; set; } = string.Empty;
        public string ItemName { get; set; } = string.Empty;
        public int ToDeptCode { get; set; }
        public string ToDeptName { get; set; } = string.Empty;
        public int ToStoreId { get; set; }
        public string ToStoreName { get; set; } = string.Empty;
        public int ToCostId { get; set; }
        public string ToCostName { get; set; } = string.Empty;
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
        public string BinNo { get; set; } = string.Empty;
        public string Remark { get; set; } = string.Empty;
    }

    public class StockTransferCreateRequestDto
    {
        public DateTime IssueDate { get; set; }
        public string IssueMode { get; set; } = "Stock Transfer";
        public string IssueSource { get; set; } = "Direct";
        public int SourceStoreId { get; set; }
        public int SourceDeptCode { get; set; }
        public int SourceDivId { get; set; }
        public string PlantName { get; set; } = string.Empty;
        public string Spindal { get; set; } = string.Empty;
        public int SlipNo { get; set; }
        public string JobCard { get; set; } = string.Empty;
        public string Remark { get; set; } = string.Empty;
        public string VehicleNo { get; set; } = string.Empty;
        public string EwayBillNo { get; set; } = string.Empty;
        public List<StockTransferLineInputDto> Lines { get; set; } = new();
    }

    public class StockTransferSaveResultDto
    {
        public string IssueCode { get; set; } = string.Empty;
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
    }

    public class StockTransferGridRecordDto
    {
        public string IssueCode { get; set; } = string.Empty;
        public DateTime IssueDate { get; set; }
        public string IssueMode { get; set; } = "Stock Transfer";
        public string IssueSource { get; set; } = "Direct";
        public int SourceStoreId { get; set; }
        public string SourceStoreName { get; set; } = string.Empty;
        public int SourceDeptCode { get; set; }
        public string SourceDeptName { get; set; } = string.Empty;
        public int SourceDivId { get; set; }
        public string PlantName { get; set; } = string.Empty;
        public string Spindal { get; set; } = string.Empty;
        public int SlipNo { get; set; }
        public string JobCard { get; set; } = string.Empty;
        public string VehicleNo { get; set; } = string.Empty;
        public string EwayBillNo { get; set; } = string.Empty;
        public double TotQty { get; set; }
        public int TotItm { get; set; }
        public double TotPcs { get; set; }
        public string Remark { get; set; } = string.Empty;
        public string CreatedBy { get; set; } = string.Empty;
        public DateTime? CreatedDate { get; set; }
    }

    public class StockTransferPagedListDto
    {
        public List<StockTransferGridRecordDto> Records { get; set; } = new();
        public int TotalCount { get; set; }
    }

    public class StockTransferDetailDto
    {
        public StockTransferGridRecordDto Header { get; set; } = new();
        public List<StockTransferLineInputDto> Lines { get; set; } = new();
    }
}
