#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Set-DefaultEnv {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Value
  )

  if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($Name))) {
    [Environment]::SetEnvironmentVariable($Name, $Value)
  }
}

Set-DefaultEnv -Name 'DATABASE_TCP_PORT' -Value '18082'
Set-DefaultEnv -Name 'DATABASE_PG_PORT' -Value '18083'
Set-DefaultEnv -Name 'DATABASE_WEB_PORT' -Value '18084'
Set-DefaultEnv -Name 'DATABASE_DBUSER' -Value 'sa'
Set-DefaultEnv -Name 'DATABASE_DBPASS' -Value 'sa'
Set-DefaultEnv -Name 'DATABASE_H2JAR' -Value './build/libs/database-specfirst.jar'
Set-DefaultEnv -Name 'DATABASE_DATA_DIR' -Value './_data'
Set-DefaultEnv -Name 'DATABASE_DBNAME' -Value 'traderx'

if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('DATABASE_HOSTNAME'))) {
  $hostName = if ([string]::IsNullOrWhiteSpace($env:HOSTNAME)) { 'localhost' } else { $env:HOSTNAME }
  [Environment]::SetEnvironmentVariable('DATABASE_HOSTNAME', $hostName)
}

if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('DATABASE_JDBC_URL'))) {
  [Environment]::SetEnvironmentVariable(
    'DATABASE_JDBC_URL',
    "jdbc:h2:tcp://$($env:DATABASE_HOSTNAME):$($env:DATABASE_TCP_PORT)/$($env:DATABASE_DBNAME)"
  )
}

if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('DATABASE_WEB_HOSTNAMES'))) {
  [Environment]::SetEnvironmentVariable('DATABASE_WEB_HOSTNAMES', $env:DATABASE_HOSTNAME)
}

Write-Host "Data will be located in $($env:DATABASE_DATA_DIR)"
Write-Host "Database name is $($env:DATABASE_DBNAME)"
Write-Host 'Running schema setup script'
Write-Host '---------------------------------------------------------------------------'

& java -cp $env:DATABASE_H2JAR org.h2.tools.RunScript `
  -url "jdbc:h2:$($env:DATABASE_DATA_DIR)/$($env:DATABASE_DBNAME);DATABASE_TO_UPPER=TRUE;TRACE_LEVEL_SYSTEM_OUT=3" `
  -user $env:DATABASE_DBUSER `
  -password $env:DATABASE_DBPASS `
  -script initialSchema.sql
if ($LASTEXITCODE -ne 0) {
  throw '[error] failed schema setup script'
}

Write-Host 'Starting Database Server'
Write-Host '---------------------------------------------------------------------------'

& java -jar $env:DATABASE_H2JAR `
  -pg -pgPort $env:DATABASE_PG_PORT -pgAllowOthers -baseDir $env:DATABASE_DATA_DIR `
  -tcp -tcpPort $env:DATABASE_TCP_PORT -tcpAllowOthers `
  -web -webPort $env:DATABASE_WEB_PORT -webExternalNames $env:DATABASE_WEB_HOSTNAMES -webAllowOthers
exit $LASTEXITCODE
