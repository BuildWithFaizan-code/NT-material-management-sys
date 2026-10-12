using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class PurchaseOrderAdvanceService : IPurchaseOrderAdvanceService
    {
        private readonly IPurchaseOrderAdvanceRepository _repo;
        private readonly ILogger<PurchaseOrderAdvanceService> _logger;

        public PurchaseOrderAdvanceService(
            IPurchaseOrderAdvanceRepository repo,
            ILogger<PurchaseOrderAdvanceService> logger)
        {
            _repo = repo;
            _logger = logger;
        }

        public async Task<IEnumerable<PoAdvancePartyLookupDto>> GetApprovedPoPartiesAsync()
        {
            return await _repo.GetApprovedPoPartiesAsync();
        }

        public async Task<IEnumerable<string>> GetApprovedPosForPartyAsync(int partyCode)
        {
            if (partyCode <= 0) return Array.Empty<string>();
            return await _repo.GetApprovedPosForPartyAsync(partyCode);
        }

        public async Task<PoAdvanceHeaderDetailsDto?> GetPoHeaderDetailsAsync(string poNo, DateTime appDate)
        {
            if (string.IsNullOrWhiteSpace(poNo)) return null;
            return await _repo.GetPoHeaderDetailsAsync(poNo.Trim(), appDate);
        }

        public async Task<IEnumerable<PoAdvanceHistoryRecordDto>> GetPoAdvanceHistoryAsync(string poNo)
        {
            if (string.IsNullOrWhiteSpace(poNo)) return Array.Empty<PoAdvanceHistoryRecordDto>();
            return await _repo.GetPoAdvanceHistoryAsync(poNo.Trim());
        }

        public async Task<IEnumerable<PoAdvanceHistoryRecordDto>> GetAllAdvancesAsync(string? searchQuery = null, int limit = 500)
        {
            return await _repo.GetAllAdvancesAsync(searchQuery, limit);
        }

        public async Task<IEnumerable<PoAdvancePartySummaryDto>> GetPartyAdvanceSummariesAsync(int partyCode)
        {
            if (partyCode <= 0) return Array.Empty<PoAdvancePartySummaryDto>();
            return await _repo.GetPartyAdvanceSummariesAsync(partyCode);
        }

        public async Task<bool> CheckDateLockAsync(DateTime date)
        {
            return await _repo.CheckDateLockAsync(date);
        }

        public async Task<int> CreateAdvanceAsync(PoAdvanceCreateRequest request, string username)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (string.IsNullOrWhiteSpace(request.PoNo)) throw new ArgumentException("Purchase order number is required.");
            if (request.PartyId <= 0) throw new ArgumentException("Valid supplier/party is required.");
            if (request.AppAmt <= 0) throw new ArgumentException("Payment amount must be greater than zero.");

            _logger.LogInformation("Creating PO Advance: PO {PoNo}, Party {PartyId}, Amt {Amt} by {User}",
                request.PoNo, request.PartyId, request.AppAmt, username);

            return await _repo.CreateAdvanceAsync(request, username);
        }

        public async Task<bool> DeleteAdvanceAsync(int poId)
        {
            if (poId <= 0) throw new ArgumentException("Valid advance ID is required.");
            _logger.LogInformation("Deleting PO Advance ID {PoId}", poId);
            return await _repo.DeleteAdvanceAsync(poId);
        }
    }
}
