#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="${ROOT}"
source "${ROOT}/pipeline/speckit/lib.sh"

COMPONENT_ID="people-service"
TARGET="${ROOT}/generated/code/components/people-service-specfirst"
TEMPLATE_ROOT="${ROOT}/templates/people-service-specfirst"
MANIFEST_PATH="${ROOT}/generated/manifests/${COMPONENT_ID}.manifest.json"

speckit_assert_global_readiness
speckit_assert_component_ready "${COMPONENT_ID}"
bash "${ROOT}/pipeline/speckit/compile-component-manifest.sh" "${COMPONENT_ID}" "${MANIFEST_PATH}"

[[ -d "${TEMPLATE_ROOT}" ]] || {
  echo "[fail] missing template directory: ${TEMPLATE_ROOT}"
  exit 1
}

[[ -f "${MANIFEST_PATH}" ]] || {
  echo "[fail] manifest was not generated: ${MANIFEST_PATH}"
  exit 1
}

jq -e '
  .schemaVersion == "1.0.0" and
  .component.id == "people-service" and
  (.runtime.defaultPort | type == "number")
' "${MANIFEST_PATH}" >/dev/null

manifest_env_by_prefix() {
  local prefix="$1"
  jq -r --arg prefix "${prefix}" '.runtime.requiredEnv[] | select(startswith($prefix))' "${MANIFEST_PATH}" | head -n 1
}

DEFAULT_PORT="$(jq -r '.runtime.defaultPort' "${MANIFEST_PATH}")"
CONTRACT_PATH="$(jq -r '.contracts.primary // ""' "${MANIFEST_PATH}")"
PEOPLE_SERVICE_PORT_ENV="$(manifest_env_by_prefix "PEOPLE_SERVICE_PORT")"
CORS_ALLOWED_ORIGINS_ENV="$(manifest_env_by_prefix "CORS_ALLOWED_ORIGINS")"

for required_var in PEOPLE_SERVICE_PORT_ENV CORS_ALLOWED_ORIGINS_ENV; do
  [[ -n "${!required_var}" ]] || {
    echo "[fail] manifest missing required runtime env mapping: ${required_var}"
    exit 1
  }
done

if [[ -n "${CONTRACT_PATH}" ]]; then
  [[ -f "${REPO_ROOT}/${CONTRACT_PATH}" ]] || {
    echo "[fail] manifest contract path does not exist: ${CONTRACT_PATH}"
    exit 1
  }
fi

rm -rf "${TARGET}"
mkdir -p "${TARGET}"
cp -R "${TEMPLATE_ROOT}/." "${TARGET}/"

cat <<EOF > "${TARGET}/README.md"
# People-Service (Spec-First Generated)

This component is synthesized from the TraderSpec Spec Kit manifest for the baseline pre-containerized runtime.

## Run

\`\`\`bash
cd PeopleService.WebApi
dotnet run
\`\`\`

## Runtime Contract

- Default port: \`${DEFAULT_PORT}\` via \`${PEOPLE_SERVICE_PORT_ENV}\`
- CORS origins: \`${CORS_ALLOWED_ORIGINS_ENV}\` (default \`*\`)
- Data source: \`PeopleJsonFilePath\` in \`appsettings.json\`
EOF

cat <<EOF > "${TARGET}/PeopleService.WebApi/Program.cs"
using Microsoft.OpenApi.Models;
using PeopleService.WebApi.Directory;

var builder = WebApplication.CreateBuilder(args);
var configuredPort = Environment.GetEnvironmentVariable("${PEOPLE_SERVICE_PORT_ENV}") ?? "${DEFAULT_PORT}";
builder.WebHost.UseUrls($"http://0.0.0.0:{configuredPort}");

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "PeopleService.WebApi", Version = "v1" });
});
builder.Services.AddSingleton<IDirectoryService, JsonDirectoryService>();

var corsAllowedOrigins = (Environment.GetEnvironmentVariable("${CORS_ALLOWED_ORIGINS_ENV}") ?? "*")
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
EOF

if [[ -n "${CONTRACT_PATH}" ]]; then
  cp "${REPO_ROOT}/${CONTRACT_PATH}" "${TARGET}/openapi.yaml"
fi

cp "${MANIFEST_PATH}" "${TARGET}/SPEC.manifest.json"

echo "[done] regenerated ${TARGET} from ${MANIFEST_PATH}"
