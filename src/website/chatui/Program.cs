using Microsoft.Extensions.Options;
using Azure.AI.Agents.Persistent;
using Azure.Identity;
using chatui.Configuration;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddJsonFile("appsettings.json", optional: true, reloadOnChange: true);
builder.Configuration
  .AddEnvironmentVariables()
  .AddUserSecrets(System.Reflection.Assembly.GetExecutingAssembly(), true);

builder.Services.AddOptions<ChatApiOptions>()
    .Bind(builder.Configuration.GetSection("AppSettings"))
    .ValidateDataAnnotations()
    .ValidateOnStart();

builder.Services.AddSingleton((provider) =>
{
    var config = provider.GetRequiredService<IOptions<ChatApiOptions>>().Value;
    // if doing local development and you get error "Token tenant does not match resource tenant", force the tenant
    var vsTenantId = config.VisualStudioTenantId;
    var credential = string.IsNullOrEmpty(vsTenantId) ?
        new DefaultAzureCredential() :
        new DefaultAzureCredential(new DefaultAzureCredentialOptions
        {
            ExcludeEnvironmentCredential = true,
            ExcludeManagedIdentityCredential = true,
            TenantId = vsTenantId
        });
    PersistentAgentsClient client = new(config.AppAgentEndpoint, credential);

    return client;
});

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

app.Run();