using System;
using System.ComponentModel.DataAnnotations;

namespace MMSERP.Api.Models
{
    public class PoAdvancePartyLookupDto
    {
        public int PCode { get; set; }
        public string PName { get; set; } = string.Empty;
    }

    public class PoAdvancePoLookupDto
    {
        public string PoNo { get; set; } = string.Empty;
    }

    public class PoAdvanceHeaderDetailsDto
    {
        public string PoNo { get; set; } = string.Empty;
        public DateTime? PoDate { get; set; }
        public decimal NetAmt { get; set; }
        public decimal TotGiv { get; set; }
        public decimal PendingAmt { get; set; }
        public string? SuppRef { get; set; }
        public string? PTerms { get; set; }
        public string? DTerms { get; set; }
        public string? Remark { get; set; }
        public string? PoMode { get; set; }
        public decimal AdvAgreed { get; set; }
    }

    public class PoAdvanceHistoryRecordDto
    {
        public int PoId { get; set; }
        public string PoNo { get; set; } = string.Empty;
        public DateTime? PoDate { get; set; }
        public DateTime? AppDt { get; set; }
        public string AppEMode { get; set; } = string.Empty;
        public DateTime? AppMDate { get; set; }
        public int PartyId { get; set; }
        public string PartyName { get; set; } = string.Empty;
        public decimal AppAmt { get; set; }
        public decimal AppLess { get; set; }
        public decimal AppBAmt { get; set; }
        public string AppRemark { get; set; } = string.Empty;
        public string AppUsrName { get; set; } = string.Empty;
        public string ChequeNo { get; set; } = string.Empty;
    }

    public class PoAdvancePartySummaryDto
    {
        public string PoNo { get; set; } = string.Empty;
        public DateTime? PoDate { get; set; }
        public decimal AppBAmt { get; set; }
        public decimal TotalAdv { get; set; }
    }

    public class PoAdvanceCreateRequest
    {
        [Required(ErrorMessage = "PO Number is required.")]
        public string PoNo { get; set; } = string.Empty;

        [Range(1, int.MaxValue, ErrorMessage = "A valid supplier/party must be selected.")]
        public int PartyId { get; set; }

        public DateTime AppDt { get; set; } = DateTime.Today;

        [Range(0.01, double.MaxValue, ErrorMessage = "Advance amount must be greater than zero.")]
        public decimal AppAmt { get; set; }

        public decimal AppLess { get; set; } = 0;

        public string? AppEMode { get; set; }

        public string? ChequeNo { get; set; }

        public string? BankName { get; set; }

        public string? AppRemark { get; set; }

        public DateTime? AppMDate { get; set; }
    }
}
