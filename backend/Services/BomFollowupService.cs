using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class BomFollowupService : IBomFollowupService
    {
        private readonly IBomFollowupRepository _repo;
        private readonly ILogger<BomFollowupService> _logger;

        public BomFollowupService(IBomFollowupRepository repo, ILogger<BomFollowupService> logger)
        {
            _repo = repo;
            _logger = logger;
        }

        public async Task<IEnumerable<BomFollowupDepartmentDto>> GetDepartmentsAsync()
        {
            return await _repo.GetDepartmentsAsync();
        }

        public async Task<IEnumerable<BomFollowupDivisionDto>> GetDivisionsAsync()
        {
            return await _repo.GetDivisionsAsync();
        }

        public async Task<IEnumerable<BomFollowupOrderTypeDto>> GetOrderTypesAsync()
        {
            return await _repo.GetOrderTypesAsync();
        }

        public async Task<IEnumerable<BomFollowupRecordDto>> GetOpenRecordsAsync(
            DateTime? asOnDate, int? departmentCode, int? divisionCode, string? orderType)
        {
            var baseDate = asOnDate ?? await _repo.GetDbDateAsync();
            var targetDate = baseDate.Date.AddHours(23).AddMinutes(59).AddSeconds(59);
            return await _repo.GetOpenRecordsAsync(targetDate, departmentCode, divisionCode, orderType);
        }

        public async Task<bool> CheckDateLockAsync(DateTime asOnDate)
        {
            return await _repo.IsDateLockedAsync(asOnDate);
        }

        public async Task<BomFollowupCloseResult> CloseBatchAsync(
            List<string> bomIds, DateTime asOnDate, string username)
        {
            if (string.IsNullOrWhiteSpace(username))
            {
                throw new ArgumentException("Username is required for BOM close.", nameof(username));
            }

            var distinctBomIds = bomIds?
                .Where(id => !string.IsNullOrWhiteSpace(id))
                .Select(id => id.Trim())
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList() ?? new List<string>();

            if (distinctBomIds.Count == 0)
            {
                return new BomFollowupCloseResult
                {
                    Success = false,
                    ClosedCount = 0,
                    Message = "No valid BOM records selected for closing.",
                    IsDateLocked = false
                };
            }

            var isLocked = await _repo.IsDateLockedAsync(asOnDate);
            if (isLocked)
            {
                _logger.LogWarning("BOM Followup close attempted on locked date {Date}", asOnDate);
                return new BomFollowupCloseResult
                {
                    Success = false,
                    ClosedCount = 0,
                    Message = $"Action rejected: Date {asOnDate:yyyy-MM-dd} is locked in LOCKDATAMST.",
                    IsDateLocked = true
                };
            }

            try
            {
                var closedCount = await _repo.CloseBomBatchAsync(distinctBomIds, asOnDate, username);
                if (closedCount != distinctBomIds.Count)
                {
                    _logger.LogError("BOM batch close discrepancy: requested {Requested}, closed {Closed}", distinctBomIds.Count, closedCount);
                    throw new InvalidOperationException($"Batch close count mismatch: requested {distinctBomIds.Count}, but {closedCount} were closed.");
                }

                _logger.LogInformation("Successfully closed {Count} BOMs by user {User}", closedCount, username);

                return new BomFollowupCloseResult
                {
                    Success = true,
                    ClosedCount = closedCount,
                    Message = $"{closedCount} Bill of Material record(s) closed successfully.",
                    IsDateLocked = false
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error while batch closing BOMs");
                throw;
            }
        }
    }
}
