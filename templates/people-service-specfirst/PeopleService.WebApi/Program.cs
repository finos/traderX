using Microsoft.OpenApi.Models;
using PeopleService.WebApi.Directory;

var builder = WebApplication.CreateBuilder(args);
var configuredPort = Environment.GetEnvironmentVariable("PEOPLE_SERVICE_PORT") ?? "18089";
builder.WebHost.UseUrls($"http://0.0.0.0:{configuredPort}");

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "PeopleService.WebApi", Version = "v1" });
});
builder.Services.AddSingleton<IDirectoryService, JsonDirectoryService>();

var corsAllowedOrigins = (Environment.GetEnvironmentVariable("CORS_ALLOWED_ORIGINS") ?? "*")
    .Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);

builder.Services.AddCors(options =>
{
    options.AddPolicy("baseline-cors", policy =>
    {
        if (corsAllowedOrigins.Length == 0 || corsAllowedOrigins.Any(origin => origin == "*"))
        {
            policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader();
            return;
        }

        policy.WithOrigins(corsAllowedOrigins).AllowAnyMethod().AllowAnyHeader();
    });
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "PeopleService.WebApi v1"));
}

app.UseCors("baseline-cors");
app.UseAuthorization();
app.MapControllers();

app.Logger.LogInformation("[ready] people-service-specfirst listening on :{Port}", configuredPort);
app.Run();
