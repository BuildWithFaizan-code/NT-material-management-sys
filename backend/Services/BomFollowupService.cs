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
            var targetDate = asOnDate.HasValue 
                ? asOnDate.Value.Date.AddHours(23).AddMinutes(59).AddSeconds(59) 
                : DateTime.UtcNow.Date.AddHours(23).AddMinutes(59).AddSeconds(59);
            return await _repo.GetOpenRecordsAsync(targetDate, departmentCode, divisionCode, orderType);
        }

        public async Task<bool> CheckDateLockAsync(DateTime asOnDate)
        {
            return await _repo.IsDateLockedAsync(asOnDate);
        }

        public async Task<BomFollowupCloseResult> CloseBatchAsync(
            List<string> bomIds, DateTime asOnDate, string username, string companyName)
        {
            if (bomIds == null || bomIds.Count == 0)
            {
                return new BomFollowupCloseResult
                {
                    Success = false,
                    ClosedCount = 0,
                    Message = "No BOM records selected for closing.",
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
                var closedCount = await _repo.CloseBomBatchAsync(bomIds, asOnDate, username, companyName);
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
