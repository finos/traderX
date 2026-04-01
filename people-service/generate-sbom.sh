#!/bin/bash
set -e

echo "Installing CycloneDX dotnet tool..."
dotnet tool restore

echo "Generating SBOM for PeopleService..."
mkdir -p build/reports
dotnet CycloneDX PeopleService.sln -o build/reports -f sbom -j -x

echo "SBOM generated successfully at build/reports/sbom.json"
