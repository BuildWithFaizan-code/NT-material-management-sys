using Microsoft.AspNetCore.Mvc;
using MMSERP.Api.Models;
using MMSERP.Api.Services;

namespace MMSERP.Api.Controllers;

[ApiController]
[Route("api/dashboard")]
public class DashboardController : ControllerBase
{
    private readonly IDashboardService _service;

    public DashboardController(IDashboardService service)
    {
        _service = service;
    }

    [HttpGet("metrics")]
    public async Task<ActionResult<ApiResponse<MetricsDto>>> GetMetrics()
    {
        var data = await _service.GetMetricsAsync();
        return Ok(ApiResponse<MetricsDto>.Ok(data));
    }

    [HttpGet("velocity")]
    public async Task<ActionResult<ApiResponse<IEnumerable<VelocityDataPoint>>>> GetVelocity(
        [FromQuery] string metricType = "Material Velocity")
    {
        var data = await _service.GetVelocityDataAsync(metricType);
        return Ok(ApiResponse<IEnumerable<VelocityDataPoint>>.Ok(data));
    }

    [HttpGet("alerts")]
    public async Task<ActionResult<ApiResponse<IEnumerable<AlertItem>>>> GetAlerts()
    {
        var data = await _service.GetAlertsAsync();
        return Ok(ApiResponse<IEnumerable<AlertItem>>.Ok(data));
    }

    [HttpGet("transactions")]
    public async Task<ActionResult<ApiResponse<IEnumerable<TransactionRecord>>>> GetTransactions()
    {
        var data = await _service.GetTransactionsAsync();
        return Ok(ApiResponse<IEnumerable<TransactionRecord>>.Ok(data));
    }

    [HttpPatch("alerts/{id:guid}/priority")]
    public async Task<ActionResult<ApiResponse<object>>> UpdateAlertPriority(
        Guid id, [FromBody] PriorityUpdateRequest request)
    {
        var validPriorities = new[] { "High", "Low" };
        if (!validPriorities.Contains(request.Priority))
        {
            return BadRequest(ApiResponse<object>.Fail(
                "Priority must be either 'High' or 'Low'."));
        }

        var updated = await _service.UpdateAlertPriorityAsync(id, request.Priority);
        if (!updated)
        {
            return NotFound(ApiResponse<object>.Fail(
                $"Alert with ID '{id}' not found."));
        }

        return Ok(ApiResponse<object>.Ok(new { id, priority = request.Priority },
            "Alert priority updated successfully."));
    }

    [HttpDelete("alerts/{id:guid}")]
    public async Task<ActionResult<ApiResponse<object>>> DeleteAlert(Guid id)
    {
        var deleted = await _service.DeleteAlertAsync(id);
        if (!deleted)
        {
            return NotFound(ApiResponse<object>.Fail(
                $"Alert with ID '{id}' not found."));
        }

        return Ok(ApiResponse<object>.Ok(new { id },
            "Alert dismissed successfully."));
    }
}
