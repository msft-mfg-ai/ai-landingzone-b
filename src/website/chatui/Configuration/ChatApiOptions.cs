using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace chatui.Configuration;

public class ChatApiOptions
{
    [Url]
    public string AppAgentEndpoint { get; init; } = default!;

    [Required]
    public string AppAgentId { get; init; } = default!;

    public string AppAgentName { get; init; } = default!;
    public string? VisualStudioTenantId { get; init; }


    public string DataProtectionKeyContainer { get; private set; } = "dataprotectionkeys";
    public bool EnableDataProtectionBlobKeyStorage { get; private set; }
    public string UserDocumentUploadBlobStorageContentContainer { get; private set; } = "content";
    public string UserDocumentUploadBlobStorageExtractContainer { get; private set; } = "content-extract";

    // Azure Storage
    public string? AzureStorageAccountEndpoint { get; init; }
    public string? AzureStorageAccountConnectionString { get; init; }
    public string? AzureStorageUserUploadContainer { get; init; }
    public string? AzureStorageContainer { get; init; }

    public bool UseManagedIdentityResourceAccess { get; init; }
    public string? UserAssignedManagedIdentityClientId { get; init; }

    [JsonPropertyName("APPLICATIONINSIGHTS_CONNECTION_STRING")]
    public string? ApplicationInsightsConnectionString { get; set; }

    // On-Behalf-Of (OBO) Flow
    [JsonPropertyName("AZURE_SP_CLIENT_ID")]
    public string? AzureServicePrincipalClientID { get; set; }
    [JsonPropertyName("AZURE_SP_CLIENT_SECRET")]
    public string? AzureServicePrincipalClientSecret { get; set; }
    [JsonPropertyName("AZURE_TENANT_ID")]
    public string? AzureTenantID { get; set; }
    [JsonPropertyName("AZURE_AUTHORITY_HOST")]
    public string? AzureAuthorityHost { get; set; }
    [JsonPropertyName("AZURE_SP_OPENAI_AUDIENCE")]
    public string? AzureServicePrincipalOpenAIAudience { get; set; }

    public string OcpApimSubscriptionHeaderName { get; init; } = "Ocp-Apim-Subscription-Key";
    public string OcpApimSubscriptionKey { get; init; } = "Ocp-Apim-Subscription-Key";
    public string XMsTokenAadAccessToken { get; init; } = "X-MS-TOKEN-AAD-ACCESS-TOKEN";
}