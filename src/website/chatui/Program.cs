Console.WriteLine("Starting ChatUI... {0}", BuildInfo.Instance);

var builder = WebApplication.CreateBuilder(args);

//builder.Services.AddEndpointsApiExplorer();
//builder.Services.AddSwaggerGen();
//builder.Services.AddOutputCache();
//builder.Services.AddCrossOriginResourceSharing();
builder.Services.AddHttpContextAccessor();


builder.Configuration.AddJsonFile("appsettings.json", optional: true, reloadOnChange: true);
builder.Configuration
  .AddEnvironmentVariables()
  .AddUserSecrets(System.Reflection.Assembly.GetExecutingAssembly(), true);

builder.Services.AddOptions<ChatApiOptions>()
    .Bind(builder.Configuration.GetSection("AppSettings"))
    .PostConfigure(options =>
    {
        // set default values for options
        options.ApplicationInsightsConnectionString = builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];
        //options.AzureServicePrincipalClientID = builder.Configuration["AZURE_SP_CLIENT_ID"];
        //options.AzureServicePrincipalClientSecret = builder.Configuration["AZURE_SP_CLIENT_SECRET"];
        //options.AzureTenantID = builder.Configuration["AZURE_TENANT_ID"];
        //options.AzureAuthorityHost = builder.Configuration["AZURE_AUTHORITY_HOST"];
        //options.AzureServicePrincipalOpenAIAudience = builder.Configuration["AZURE_SP_OPENAI_AUDIENCE"];
    })
    .ValidateDataAnnotations()
    .ValidateOnStart();

var appConfiguration = new ChatApiOptions();
builder.Configuration.Bind(appConfiguration);

Console.WriteLine("Chatting with Agent {0} at {1}", builder.Configuration["AppSettings:AppAgentId"], builder.Configuration["AppSettings:AppAgentEndpoint"]);

if (appConfiguration.UseManagedIdentityResourceAccess)
    builder.Services.AddAzureWithMICredentialsServices(appConfiguration);
else
    builder.Services.AddAzureServices(appConfiguration);

builder.Services.AddSingleton((provider) =>
{
    var config = provider.GetRequiredService<IOptions<ChatApiOptions>>().Value;
    // if doing local development and you get error "Token tenant does not match resource tenant", force the tenant
    var vsTenantId = config.VisualStudioTenantId;
    var credential = CredentialsHelper.GetCredentials(vsTenantId, config.UserAssignedManagedIdentityClientId);
    Console.WriteLine($"Created credentials of type {CredentialsHelper.CredentialType} to access {config.AppAgentEndpoint}");
    PersistentAgentsClient client = new(config.AppAgentEndpoint, credential);
    return client;
});

if (builder.Environment.IsDevelopment())
{
    builder.Services.AddDistributedMemoryCache();
}
else
{
    // set application telemetry
    if (!string.IsNullOrEmpty(appConfiguration.ApplicationInsightsConnectionString))
    {
        builder.Services.AddApplicationInsightsTelemetry((option) =>
        {
            option.ConnectionString = appConfiguration.ApplicationInsightsConnectionString;
        });
    }

    if (appConfiguration.EnableDataProtectionBlobKeyStorage && !string.IsNullOrEmpty(appConfiguration.AzureStorageAccountConnectionString))
    {
        var containerName = appConfiguration.DataProtectionKeyContainer;
        var storageAccount = appConfiguration.AzureStorageAccountEndpoint;
        var fileName = "keys.xml";

        builder.Services.AddDataProtection().PersistKeysToAzureBlobStorage(storageAccount, containerName, fileName)
            .SetApplicationName("ChatUI")
            .SetDefaultKeyLifetime(TimeSpan.FromDays(90));
    }
}

builder.Services.AddControllersWithViews();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAllOrigins",
        builder =>
        {
            builder.AllowAnyOrigin()
                   .AllowAnyMethod()
                   .AllowAnyHeader();
        });
});

var app = builder.Build();

app.UseStaticFiles();

app.UseRouting();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.UseCors("AllowAllOrigins");

Console.WriteLine("Running ChatUI... {0}", BuildInfo.Instance);

app.Run();