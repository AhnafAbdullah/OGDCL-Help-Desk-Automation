using Microsoft.AspNetCore.Components;

namespace Ogdcl.Web.Services;

/// <summary>
/// Base for all authenticated pages: redirects to /login when there is no
/// session and funnels API errors into a banner instead of crashing the circuit.
/// </summary>
public abstract class AppPage : ComponentBase
{
    [Inject] protected AuthState Auth { get; set; } = default!;
    [Inject] protected ApiClient Api { get; set; } = default!;
    [Inject] protected NavigationManager Nav { get; set; } = default!;

    protected string? Error;
    protected bool Loading = true;

    protected override async Task OnInitializedAsync()
    {
        await Auth.EnsureLoadedAsync();
        if (!Auth.IsLoggedIn)
        {
            Nav.NavigateTo("/login");
            return;
        }

        await Try(LoadAsync);
        Loading = false;
    }

    /// <summary>Page data load; override in pages.</summary>
    protected virtual Task LoadAsync() => Task.CompletedTask;

    /// <summary>Runs an API action, mapping failures to the error banner.</summary>
    protected async Task Try(Func<Task> action)
    {
        Error = null;
        try
        {
            await action();
        }
        catch (ApiException ex) when (ex.StatusCode == 401)
        {
            // The token was rejected (expired/rotated). Clear the whole session
            // before redirecting — leaving it in place keeps the sidebar visible
            // and makes the login page bounce straight back, causing a flicker loop.
            await Auth.SignOutAsync();
            Nav.NavigateTo("/login");
        }
        catch (ApiException ex)
        {
            Error = ex.Message;
        }
        catch (HttpRequestException)
        {
            Error = "Cannot reach the API server. Is it running?";
        }
        catch (Exception ex)
        {
            // Never let an unexpected error tear down the Blazor circuit;
            // surface it in the banner so the page stays usable.
            Error = $"Unexpected error: {ex.Message}";
        }
        StateHasChanged();
    }
}
