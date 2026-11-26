using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.IdentityModel.Tokens;
using PeopleService.WebApi.Directory;
using PeopleService.WebApi.Security;

var builder = WebApplication.CreateBuilder(args);
// Deployment may supply Kestrel TLS configuration. Cleartext is an explicit
// loopback fixture option and never binds all interfaces by default.
if (Environment.GetEnvironmentVariable("LAB_PEOPLE_LOOPBACK_PORT") is string port)
{
    if (!int.TryParse(port, out var number) || number < 1 || number > 65535)
        throw new InvalidOperationException("Invalid fixture port");
    builder.WebHost.UseUrls($"http://127.0.0.1:{number}");
}
else if (!Uri.TryCreate(builder.Configuration["Kestrel:Endpoints:Https:Url"], UriKind.Absolute, out var endpoint)
    || endpoint.Scheme != "https" || string.IsNullOrEmpty(endpoint.Host) || endpoint.UserInfo != "")
    throw new InvalidOperationException("Explicit HTTPS endpoint required");

var trust = DirectoryTrust.Load();
builder.Services.AddControllers();
builder.Services.AddSingleton<IDirectoryService, JsonDirectoryService>();
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(options =>
{
    options.MapInboundClaims = false;
    options.SaveToken = false;
    options.IncludeErrorDetails = false;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        RequireSignedTokens = true, ValidateIssuerSigningKey = true,
        IssuerSigningKey = trust.Key, ValidAlgorithms = [SecurityAlgorithms.RsaSha256],
        ValidateIssuer = true, ValidIssuer = trust.Issuer,
        ValidateAudience = true, ValidAudience = trust.Audience,
        RequireExpirationTime = true, ValidateLifetime = true, ClockSkew = TimeSpan.Zero
    };
    options.Events = new JwtBearerEvents
    {
        OnTokenValidated = context =>
        {
            if (!trust.ValidClaims(context.Principal)) context.Fail("Invalid identity");
            return Task.CompletedTask;
        }
    };
});
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("directory-operator", policy => policy.RequireAuthenticatedUser()
        .RequireAssertion(context => trust.IsOperator(context.User)));
    options.FallbackPolicy = new AuthorizationPolicyBuilder().RequireAuthenticatedUser()
        .RequireAssertion(_ => false).Build();
});

var app = builder.Build();
app.UseExceptionHandler(handler => handler.Run(async context =>
{
    context.Response.StatusCode = 503;
    await context.Response.WriteAsJsonAsync(new { error = "Directory unavailable" });
}));
app.Use(async (context, next) =>
{
    context.Response.Headers.CacheControl = "no-store";
    context.Response.Headers["X-Content-Type-Options"] = "nosniff";
    if (context.Request.Method != "GET" || !DirectoryTrust.Routes.Contains(context.Request.Path.Value ?? ""))
    {
        context.Response.StatusCode = 404; return;
    }
    await next(context);
});
app.UseAuthentication();
app.UseAuthorization();
app.MapGet("/health/alive", () => Results.Json(new { status = "UP" })).AllowAnonymous();
app.MapControllers().RequireAuthorization("directory-operator");
app.Run();
