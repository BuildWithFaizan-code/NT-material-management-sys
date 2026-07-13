namespace MMSERP.Api.Models;

public record PriorityUpdateRequest
{
    public string Priority { get; init; } = "Low";
}
