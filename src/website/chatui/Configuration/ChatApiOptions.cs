using System.ComponentModel.DataAnnotations;

namespace chatui.Configuration;

public class ChatApiOptions
{
    [Url]
    public string AppAgentEndpoint { get; init; } = default!;

    [Required]
    public string AppAgentId { get; init; } = default!;

    public string AppAgentName { get; init; } = default!;

    public string? VisualStudioTenantId { get; init; }
}