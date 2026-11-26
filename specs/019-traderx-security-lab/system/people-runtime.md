# .NET people-service private runtime contract

This is a bounded, opt-in adapter candidate for the operator-only people-service.
It is a prerequisite input to S019-06a3b3, not completion of that task or
acceptance of an integrated deployment. It does not modify the existing host
fixture or enable a deployment cutover.

## Runtime and projection contract

The container runs as UID/GID `10001` and invokes
`scripts/security-lab/people_runtime.py` after projecting exactly these keys
from `/run/projected`:

| Projected key | Materialized path | Purpose |
| --- | --- | --- |
| `config.json` | `/run/private/config/config.json` | Strict non-secret runtime schema |
| `identity-public.pem` | `/run/private/config/identity-public.pem` | RSA JWT verification key |
| `identity-roles.json` | `/run/private/config/identity-roles.json` | Private subject-to-role grants |
| `server-cert.pem` | `/run/private/config/server-cert.pem` | HTTPS server certificate chain |
| `server-key.pem` | `/run/private/config/server-key.pem` | HTTPS server private key |

The launcher checks the projection key inventory and delegates copying to the
existing `private_materializer.py`. The materializer resolves one projected
generation, rejects path escapes, non-regular files, unsafe ownership or mode,
oversized files, and duplicate keys in its requested inventory. The launcher
then requires a UID/GID of `10001`, an owned `0700` private directory, and exact
owned `0600` regular, single-link files with bounded sizes. The launcher has no
source, destination, command, port or application-path arguments. Replacing
configuration requires a fresh private volume/pod rather than overwriting an
existing materialization.

`config.json` is UTF-8 JSON with duplicate keys and unknown keys rejected. Its
complete v1 shape is:

```json
{
  "version": 1,
  "issuer": "https://identity.example.invalid/issuer",
  "audience": "traderx-people-service",
  "key_not_after": "2027-01-01T00:00:00Z",
  "public_key_file": "/run/private/config/identity-public.pem",
  "roles_file": "/run/private/config/identity-roles.json",
  "server_certificate_file": "/run/private/config/server-cert.pem",
  "server_key_file": "/run/private/config/server-key.pem"
}
```

`version` is the integer `1`; issuer must be an HTTPS URI without credentials,
query or fragment; audience is a bounded non-empty string; and `key_not_after`
is a future RFC 3339 timestamp with an explicit timezone. All four file paths
must exactly equal the fixed materialized paths shown above. The public key is
SPKI PEM with the RSA algorithm identifier and at least 2048 bits. The role file
is a non-empty JSON object of at most 1024 bounded subject strings mapped only
to `operator`, `trader` or `read-only`; duplicate JSON keys are rejected.
Kestrel must successfully load the PEM certificate and matching unencrypted
PEM private key. The server key is never passed as an argument or environment
value; only its fixed materialized path is provided to Kestrel. Encrypted keys
are refused without an interactive password prompt, even when stdin is open.

## Application mapping and compatibility

After rejecting inherited ASP.NET Core, .NET, Kestrel, `LAB_*`, and generic
double-underscore configuration variables, the launcher constructs a fresh,
minimal application environment. It maps `issuer`, `audience`, `key_not_after`,
the public key path and role path to the exact `LAB_IDENTITY_*` names consumed
by the existing `DirectoryTrust.Load()`. That code performs the final lifetime,
RSA import, issuer/audience, signature and operator-role checks.

The launcher supplies only the Kestrel `Https` endpoint at
`https://0.0.0.0:18089`, using Kestrel's PEM `Certificate:Path` and `KeyPath`.
It does not set `LAB_PEOPLE_LOOPBACK_PORT`, `ASPNETCORE_URLS`, or any HTTP
endpoint. It invokes only `/usr/share/dotnet/dotnet` with
`/opt/traderx/PeopleService.WebApi.dll` and the fixed private content root.
Running with `/run/private/config` as content root prevents appsettings files
from supplying another endpoint; only the launcher's fresh environment and
fixed arguments configure the host. There is no PKCS#12 password and no
plaintext or loopback override. The current app still owns route filtering,
operator authorization, JWT claim validation, and no-store response behavior.

`JsonDirectoryService` otherwise resolves `MockDirectory/people.json` under
that private content root. The launcher therefore sets the non-secret
`PeopleJsonFilePath` to the fixed absolute path
`/opt/traderx/MockDirectory/people.json`. The future image must package the
reviewed synthetic directory asset at exactly that location and verify its
bytes; it is not another projected Secret or a caller-configurable path.
An authenticated operator lookup against that packaged asset remains a hosted
acceptance requirement. HTTPS liveness alone cannot prove directory usability.

The strict projection and launcher are additive; they do not change
`Program.cs`, `DirectoryTrust.cs`, existing host-fixture semantics, image
builders, integrated deployment configuration or workflows. The published
artifact must place the app DLL and runtime at the fixed paths above and invoke
this launcher; that packaging work is not included here.

## Safe logging and acceptance boundary

All launcher validation, materialization and exec failures produce only
`People service private configuration refused; details withheld.` The launcher
does not print exception strings, JSON values, PEM bytes, key material, tokens,
passwords, argv configuration or environment contents. Trust paths, issuer and
audience are non-secret values and are passed only through the app's documented
configuration interface.

Unit tests exercise schema and trust rejection, file/projection boundaries,
environment contamination, fixed HTTPS/exec/directory arguments and sanitized
failure output without Docker or starting the .NET application. A real PEM
regression checks successful certificate loading and bounded encrypted-key
rejection with no OpenSSL prompt. They do not prove image
contents, actual Kestrel HTTPS startup, TLS client verification, operator token
authorization, directory behavior or cluster policy. Those remain explicit
hosted-image and integrated acceptance gates for S019-06a3b3 and the broader
S019-06a3 work.
