using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;

namespace Tarazpad.Desktop.Services;

public sealed class TarazpadApiClient
{
    private readonly HttpClient _http = new() { Timeout = TimeSpan.FromSeconds(25) };
    private readonly JsonSerializerOptions _json = new() { PropertyNameCaseInsensitive = true };

    public string ServerUrl { get; private set; } = "http://127.0.0.1:8080";
    public string? Token { get; private set; }
    public string? UserName { get; private set; }

    public void Configure(string serverUrl)
    {
        var normalized = (serverUrl ?? string.Empty).Trim().TrimEnd('/');
        if (!Uri.TryCreate(normalized, UriKind.Absolute, out var uri) || (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
            throw new ArgumentException("آدرس سرور معتبر نیست.");
        ServerUrl = normalized;
    }

    public async Task<bool> HealthAsync(CancellationToken cancellationToken = default)
    {
        using var response = await _http.GetAsync(BuildUri("api/health"), cancellationToken);
        if (!response.IsSuccessStatusCode) return false;
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync(cancellationToken));
        return json.RootElement.TryGetProperty("ok", out var ok) && ok.GetBoolean();
    }

    public async Task LoginAsync(string email, string password, CancellationToken cancellationToken = default)
    {
        using var response = await _http.PostAsJsonAsync(BuildUri("api/auth/login"), new { email, password }, cancellationToken);
        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException(response.StatusCode == System.Net.HttpStatusCode.Unauthorized ? "نام کاربری یا رمز عبور صحیح نیست." : $"ورود ناموفق بود: {body}");

        using var doc = JsonDocument.Parse(body);
        var root = doc.RootElement;
        Token = FindString(root, "token") ?? FindString(root, "accessToken") ?? FindString(root, "access_token");
        if (string.IsNullOrWhiteSpace(Token)) throw new InvalidOperationException("توکن ورود از سرور دریافت نشد.");
        UserName = FindString(root, "fullName") ?? FindString(root, "name") ?? email;
        _http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", Token);
    }

    public async Task<JsonElement> GetJsonAsync(string relativeUrl, CancellationToken cancellationToken = default)
    {
        using var response = await _http.GetAsync(BuildUri(relativeUrl), cancellationToken);
        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode) throw new InvalidOperationException(ToFriendlyError(response.StatusCode, body));
        using var doc = JsonDocument.Parse(body);
        return doc.RootElement.Clone();
    }

    public async Task<JsonElement> SendJsonAsync(HttpMethod method, string relativeUrl, object payload, CancellationToken cancellationToken = default)
    {
        var request = new HttpRequestMessage(method, BuildUri(relativeUrl))
        {
            Content = new StringContent(JsonSerializer.Serialize(payload, _json), Encoding.UTF8, "application/json")
        };
        using var response = await _http.SendAsync(request, cancellationToken);
        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode) throw new InvalidOperationException(ToFriendlyError(response.StatusCode, body));
        if (string.IsNullOrWhiteSpace(body)) return JsonDocument.Parse("{}").RootElement.Clone();
        using var doc = JsonDocument.Parse(body);
        return doc.RootElement.Clone();
    }

    private Uri BuildUri(string relativeUrl) => new($"{ServerUrl}/{relativeUrl.TrimStart('/')}", UriKind.Absolute);

    private static string? FindString(JsonElement root, string name)
    {
        if (root.ValueKind != JsonValueKind.Object) return null;
        foreach (var prop in root.EnumerateObject())
        {
            if (string.Equals(prop.Name, name, StringComparison.OrdinalIgnoreCase) && prop.Value.ValueKind == JsonValueKind.String)
                return prop.Value.GetString();
            if (prop.Value.ValueKind == JsonValueKind.Object)
            {
                var nested = FindString(prop.Value, name);
                if (!string.IsNullOrWhiteSpace(nested)) return nested;
            }
        }
        return null;
    }

    private static string ToFriendlyError(System.Net.HttpStatusCode status, string body)
    {
        try
        {
            using var doc = JsonDocument.Parse(body);
            if (doc.RootElement.TryGetProperty("error", out var error)) return $"خطای سرور ({(int)status}): {error}";
            if (doc.RootElement.TryGetProperty("message", out var message)) return $"خطای سرور ({(int)status}): {message}";
        }
        catch { }
        return $"خطای سرور ({(int)status}).";
    }
}
