namespace chatui.API;

[ApiController]
[Route("[controller]/[action]")]

public class ChatController(
    PersistentAgentsClient client,
    IOptionsMonitor<ChatApiOptions> options,
    ILogger<ChatController> logger) : ControllerBase
{
    private readonly PersistentAgentsClient _client = client;
    private readonly IOptionsMonitor<ChatApiOptions> _options = options;
    private readonly ILogger<ChatController> _logger = logger;

    // TODO: [security] Do not trust client to provide threadId. Instead map current user to their active threadid in your application's own state store.
    // Without this security control in place, a user can inject messages into another user's thread.
    [HttpPost("{threadId}")]
    public async Task<IActionResult> Completions([FromRoute] string threadId, [FromBody] string prompt)
    {

        if (string.IsNullOrWhiteSpace(prompt))
            throw new ArgumentException("Prompt cannot be null, empty, or whitespace.", nameof(prompt));

        _logger.LogInformation($"API Completions: Starting... Thread: {threadId}  Prompt: {prompt}");
        try
        {
            var _config = _options.CurrentValue;

            PersistentThreadMessage message = await _client.Messages.CreateMessageAsync(
                threadId,
                MessageRole.User,
                prompt);

            ThreadRun run = await _client.Runs.CreateRunAsync(threadId, _config.AppAgentId);

            while (run.Status == RunStatus.Queued || run.Status == RunStatus.InProgress || run.Status == RunStatus.RequiresAction)
            {
                await Task.Delay(TimeSpan.FromMilliseconds(500));
                run = (await _client.Runs.GetRunAsync(threadId, run.Id)).Value;
            }

            Pageable<PersistentThreadMessage> messages = _client.Messages.GetMessages(
                threadId: threadId, order: ListSortOrder.Ascending);

            var fullText =
                messages
                    .Where(m => m.Role == MessageRole.Agent)
                    .SelectMany(m => m.ContentItems.OfType<MessageTextContent>())
                    .Last().Text;

            return Ok(new { data = fullText });
        }
        catch (RequestFailedException ex)
        {
            _logger.LogError($"API Completions: Error: Thread: {threadId} Prompt: {prompt} - Error: {ex.Message}");
            return StatusCode(ex.Status, new { error = ex.Message });
        }
    }
    [HttpPost]
    public async Task<IActionResult> Threads()
    {
        _logger.LogInformation($"API Threads: Starting ...");
        try
        {
            // TODO [performance efficiency] Delay creating a thread until the first user message arrives.
            PersistentAgentThread thread = await _client.Threads.CreateThreadAsync();

            return Ok(new { id = thread.Id });
        }
        catch (RequestFailedException ex)
        {
            _logger.LogError($"API Threads: Error: {ex.Message}");
            return StatusCode(ex.Status, new { error = ex.Message });
        }
    }
    [HttpGet]
    public async Task<IActionResult> Info()
    {
        _logger.LogInformation($"API Info: Starting...");
        _ = await Task.FromResult(true);
        try
        {
            var buildinfo = BuildInfo.Create();
            _logger.LogInformation($"API Info: Build Number: {buildinfo.BuildNumber} Date: {buildinfo.BuildDate}");
            return Ok(new { data = buildinfo });
        }
        catch (Exception ex)
        {
            _logger.LogError($"API Info: Error: {ex.Message}");
            return StatusCode(500, new { error = ex.Message });
        }
    }
}