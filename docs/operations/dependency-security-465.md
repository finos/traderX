# Dependency security remediation (#465)

The source baseline includes the H2 connection-retirement and after-commit
publication fixes from #461 / PR #463. Do not publish a replacement snapshot
from a source revision that omits those fixes. This change does not authorize
a demo deployment or a new security exception.

## Version decisions

The complete HTML reports and failed-job logs for [state 002](https://github.com/finos/traderX/actions/runs/35203378098)
and [state 004](https://github.com/finos/traderX/actions/runs/35204061241)
report the dependency families below. Multer is included here even though
it was omitted from the issue's initial examples. All original state 004 image
scan jobs passed; replacement images still require fresh scans.

| Dependency | Old version | Replacement | Evidence |
| --- | --- | --- | --- |
| qs | 6.15.2 | 6.16.0 | [GHSA-4mjr-xmp4-gh2g](https://github.com/advisories/GHSA-4mjr-xmp4-gh2g) |
| Multer | 2.2.0 | 2.3.0 | [GHSA-535w-7cp7-47q4](https://github.com/advisories/GHSA-535w-7cp7-47q4), [GHSA-qfvm-cv95-jqjf](https://github.com/advisories/GHSA-qfvm-cv95-jqjf), [GHSA-wc9g-mqfw-jrwm](https://github.com/advisories/GHSA-wc9g-mqfw-jrwm) |
| Spring Framework | 6.2.19 | 7.0.9 via Boot 4.0.8 | Vendor advisories below |
| Spring Data JPA | 3.5.13 | 4.0.7 via Boot 4.0.8 | [CVE-2026-47834](https://spring.io/security/cve-2026-47834/) |
| Embedded Tomcat | 10.1.57 | 11.0.26 | [Tomcat 11 security advisories](https://tomcat.apache.org/security-11.html), fixes in 11.0.25 |

The Spring 6.2.20 and Data JPA 3.5.14 fixes are enterprise-only and are not
available from Maven Central. Boot 4.0.8 provides the patched public Spring
Framework and Data JPA releases. Java 21 and Gradle 8.14.5 remain supported.
Springdoc moves to 3.0.3 for Boot 4 compatibility, and Jackson moves to Boot's
3.1.5 baseline. The Socket.IO and NATS adapters use Jackson 3's immutable mapper
builder while retaining null omission and the existing message envelope.
Jackson annotations retain their `com.fasterxml.jackson.annotation` package.
See the [Boot migration guide](https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-4.0-Migration-Guide)
and [Springdoc compatibility information](https://springdoc.org/).

A fresh npm audit additionally reports [GHSA-2m8v-j782-fhvr](https://github.com/advisories/GHSA-2m8v-j782-fhvr) in Socket.IO parser 4.2.6. The canonical override is therefore 4.2.7, including browser and pricing-publisher dependencies.

## Complete reported Java finding inventory

All findings below are addressed by upgrading; no applicability suppression or
scan-threshold reduction is introduced. Scanner severity is not an independent
exploitability assessment.

Spring Framework fixes are documented individually by the vendor:

- [CVE-2026-47883](https://spring.io/security/cve-2026-47883/)
- [CVE-2026-47884](https://spring.io/security/cve-2026-47884/)
- [CVE-2026-47885](https://spring.io/security/cve-2026-47885/)
- [CVE-2026-47886](https://spring.io/security/cve-2026-47886/)
- [CVE-2026-47887](https://spring.io/security/cve-2026-47887/)
- [CVE-2026-47888](https://spring.io/security/cve-2026-47888/)
- [CVE-2026-47889](https://spring.io/security/cve-2026-47889/)
- [CVE-2026-47890](https://spring.io/security/cve-2026-47890/)
- [CVE-2026-47891](https://spring.io/security/cve-2026-47891/)
- [CVE-2026-47892](https://spring.io/security/cve-2026-47892/)
- [CVE-2026-47893](https://spring.io/security/cve-2026-47893/)
- [CVE-2026-59281](https://spring.io/security/cve-2026-59281/)
- [CVE-2026-59282](https://spring.io/security/cve-2026-59282/)
- [CVE-2026-59283](https://spring.io/security/cve-2026-59283/)
- [CVE-2026-59313](https://spring.io/security/cve-2026-59313/)

The Tomcat findings are CVE-2026-65182, CVE-2026-65183, CVE-2026-65637,
CVE-2026-65905, CVE-2026-65927, CVE-2026-66299, CVE-2026-66422,
CVE-2026-68525, CVE-2026-68569, CVE-2026-68763, and CVE-2026-73180.
The vendor lists all eleven as fixed in 11.0.25; 11.0.26 includes those fixes.

## Generation and release

Canonical versions live in `catalog/dependency-version-targets.json` and the
templates. State patchsets must carry the same Java baseline and Jackson API
changes. Generation synchronizes Node overrides and refreshes lockfiles; verify
the resolved versions as well as manifest pins before publication.

Regenerate states sequentially, including 002 and 004, with an isolated
`TRADERX_GENERATED_ROOT` when another task is using the normal output directory.
Run repository gates, booking regressions, application builds, and dependency
and image scans before using `pipeline/publish-generated-state-branch.sh`.
Each published generated branch must remain one snapshot commit above its
parent. Record source and snapshot revisions and scan runs in the remediation
PR. Descendant states inherit this baseline and require regeneration before
their next publication.

## Runtime image remediation

Fresh Trivy scans also found OS and bundled npm-tooling vulnerabilities in the
old Node 20 Alpine images and Debian-based .NET image. Node 20 is EOL according
to the [Node release schedule](https://nodejs.org/en/about/previous-releases).
The Node services now build on Node 24 LTS and run compiled code with production
dependencies, updated Alpine packages, and no bundled npm/Yarn tooling. Runtime
files belong to the unprivileged node user. The people service uses
`aspnet:9.0-noble-chiseled-extra`, retaining ICU/timezone support while omitting
unneeded Debian utilities; see [Microsoft's image guidance](https://learn.microsoft.com/en-us/dotnet/core/docker/container-images).
The catalog's `docker.runtimeImages` entries and generated-target validator
guard these final runtime stages. No image finding is suppressed.

## Validation record (2026-09-17)

- All four repository quality gates and the documentation website build pass.
- H2 schema lifetime and after-commit publication tests pass for baseline and pricing templates.
- The added wire-contract test checks the legacy `accountID` input alias, numeric envelope date, enum and quantity values, and omission of null fields. It caught Jackson 3's changed date default before explicit timestamp configuration was added.
- State 002 and 004 application builds pass. All four Java services start and serve OpenAPI documents; account and position endpoint smoke checks pass.
- Nine state 004 runtime dependency scans pass at CVSS 5 with the existing suppressions. Inputs were resolved npm lockfiles, built Java archives, and .NET output. Dependency-Check 13.0.0 used the CI action image's September 16 database copied into the native scanner image. Live NVD updates failed, so stale local cached data was not used to establish a pass. OSS Index was unavailable without credentials, as in the existing CI setup.
- All ten state 004 images build and pass Trivy 0.74.0 HIGH/CRITICAL scans. Local images are Linux ARM64; remote CI must validate the published snapshot and its target architecture independently. Images were exported before scanning to avoid concurrent local image cleanup.
- No demo deployment was performed. Remote snapshot checks and publication revisions must be recorded in the PR before treating the issue's release acceptance criteria as complete.

The first replacement state 002 CI scan additionally found Angular advisories
[GHSA-jhpw-976m-542j](https://github.com/angular/angular/security/advisories/GHSA-jhpw-976m-542j),
[GHSA-jj27-h5hq-8x99](https://github.com/angular/angular/security/advisories/GHSA-jj27-h5hq-8x99), and
[GHSA-hh8m-fm6v-7cvg](https://github.com/angular/angular/security/advisories/GHSA-hh8m-fm6v-7cvg).
Angular framework and tooling minimums are raised to 20.3.28; regenerated lockfiles
and remote checks are required because the earlier local scan did not detect these findings.

Full HTML artifact review also includes low-severity Spring CVE-2026-59280 and
CVE-2026-59314 (covered by Framework 7.0.9), qs GHSA-x5fp-wj9c-mxmx
(covered by 6.16.0), Multer GHSA-qvfw-j98x-7q72 (covered by 2.3.0), and
body-parser GHSA-v422-hmwv-36x6 (explicit reference-data override to 2.3.0).
The reports retain the pre-existing CVE-2026-53914 suppression; this change adds no exception.
