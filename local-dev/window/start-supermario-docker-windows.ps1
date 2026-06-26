param(
  [Parameter(Position = 0)]
  [ValidateSet("up", "start", "foreground", "logs", "ps", "status", "stop", "down", "rebuild", "help")]
  [string]$Action = "up",

  [Parameter(Position = 1)]
  [ValidateSet("localhost", "ip")]
  [string]$HostMode = $(if ($env:SUPERMARIO_HOST_MODE) { $env:SUPERMARIO_HOST_MODE } else { "localhost" })
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LocalDevDir = Resolve-Path (Join-Path $ScriptDir "..")
$InfraDir = Resolve-Path (Join-Path $LocalDevDir "..")
$ProjectRoot = Resolve-Path (Join-Path $InfraDir "..")
$ComposeFile = Join-Path $LocalDevDir "docker-compose.local.yml"
$LocalComposeEnvFile = Join-Path $LocalDevDir "local-dev.compose.env"
$LlmEnvFile = Join-Path $ProjectRoot "SuperMario_LLM\.env"
$LlmEnvExample = Join-Path $ProjectRoot "SuperMario_LLM\.env.example"

function Write-Usage {
  @"
Usage:
  .\window\start-supermario-docker-windows.ps1 [command] [host-mode]

Host modes:
  localhost  Use localhost URLs. Default.
  ip         Detect this PC's LAN IP and expose URLs for phone testing.

Commands:
  up          Build and start all local services in the background. Default.
  start       Same as up.
  foreground  Build and start all local services in the foreground.
  logs        Follow logs.
  ps          Show container status.
  stop        Stop containers without removing them.
  down        Stop and remove containers.
  rebuild     Rebuild and recreate containers.

Local URLs:
  React:   http://localhost:5173
  Django:  http://localhost:8000/api/engine/health
  LLM:     http://localhost:8001/llm/health
"@
}

function Write-DockerHubAuthHelp {
  @"

Docker Hub image pull failed.

If the error says "failed to fetch oauth token" or "401 Unauthorized",
refresh Docker Desktop's Docker Hub credentials:

  docker logout
  docker login

Then rerun:

  .\window\start-supermario-docker-windows.ps1 up

"@ | Write-Error
}

function Get-LanIp {
  $routes = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
    Sort-Object RouteMetric, InterfaceMetric

  foreach ($route in $routes) {
    $ip = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue |
      Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } |
      Select-Object -First 1 -ExpandProperty IPAddress
    if ($ip) {
      return $ip
    }
  }

  $fallbackIp = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } |
    Select-Object -First 1 -ExpandProperty IPAddress
  if ($fallbackIp) {
    return $fallbackIp
  }

  throw "Could not detect this PC's LAN IP. Check network connection."
}

function Invoke-Compose {
  param([string[]]$ComposeArgs)

  if ($script:ComposeCommand -eq "docker") {
    & docker compose --env-file $LocalComposeEnvFile -f $ComposeFile @ComposeArgs
  } else {
    & docker-compose --env-file $LocalComposeEnvFile -f $ComposeFile @ComposeArgs
  }

  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

function Invoke-ComposeStart {
  param([string[]]$ComposeArgs)

  if ($script:ComposeCommand -eq "docker") {
    & docker compose --env-file $LocalComposeEnvFile -f $ComposeFile @ComposeArgs
  } else {
    & docker-compose --env-file $LocalComposeEnvFile -f $ComposeFile @ComposeArgs
  }

  if ($LASTEXITCODE -ne 0) {
    Write-DockerHubAuthHelp
    exit $LASTEXITCODE
  }
}

Set-Location $LocalDevDir

if (!(Test-Path $ComposeFile)) {
  Write-Error "Missing compose file: $ComposeFile"
}

$requiredDirs = @(
  @{ Path = Join-Path $ProjectRoot "SuperMario_Django\backend"; Label = "Django backend" },
  @{ Path = Join-Path $ProjectRoot "SuperMario_React"; Label = "React frontend" },
  @{ Path = Join-Path $ProjectRoot "SuperMario_LLM"; Label = "LLM server" }
)

foreach ($item in $requiredDirs) {
  if (!(Test-Path $item.Path)) {
    Write-Error "Missing $($item.Label) directory: $($item.Path)"
  }
}

if (!(Test-Path $LocalComposeEnvFile)) {
  New-Item -ItemType File -Path $LocalComposeEnvFile | Out-Null
}

if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Error "Docker is not installed. Install Docker Desktop first."
}

& docker info *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Error "Docker is not running. Start Docker Desktop and try again."
}

& docker compose version *> $null
if ($LASTEXITCODE -eq 0) {
  $script:ComposeCommand = "docker"
} elseif (Get-Command docker-compose -ErrorAction SilentlyContinue) {
  $script:ComposeCommand = "docker-compose"
} else {
  Write-Error "Docker Compose is not available. Install or update Docker Desktop."
}

if (!(Test-Path $LlmEnvFile)) {
  if (Test-Path $LlmEnvExample) {
    Copy-Item $LlmEnvExample $LlmEnvFile
    Write-Host "Created $LlmEnvFile from .env.example. Fill API keys if LLM calls need them."
  } else {
    @"
APP_ENV=local
LLM_API_PREFIX=/llm
OPENAI_API_KEY=
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
"@ | Set-Content -Encoding UTF8 $LlmEnvFile
    Write-Host "Created default $LlmEnvFile. Fill API keys if LLM calls need them."
  }
}

switch ($HostMode) {
  "localhost" {
    $env:LOCAL_DEV_HOST_IP = "localhost"
  }
  "ip" {
    $env:LOCAL_DEV_HOST_IP = Get-LanIp
  }
}

$ReactUrl = "http://$($env:LOCAL_DEV_HOST_IP):5173"
$DjangoHealthUrl = "http://$($env:LOCAL_DEV_HOST_IP):8000/api/engine/health"
$LlmHealthUrl = "http://$($env:LOCAL_DEV_HOST_IP):8001/llm/health"

switch ($Action) {
  { $_ -in @("up", "start") } {
    Invoke-ComposeStart @("up", "--build", "-d")
    Invoke-Compose @("ps")
    @"

SuperMario local stack is starting.

Mode:
  Host:    $HostMode

Open:
  React:   $ReactUrl
  Django:  $DjangoHealthUrl
  LLM:     $LlmHealthUrl

Follow logs:
  .\window\start-supermario-docker-windows.ps1 logs
"@ | Write-Host
  }
  "foreground" {
    Invoke-ComposeStart @("up", "--build")
  }
  "logs" {
    Invoke-Compose @("logs", "-f")
  }
  { $_ -in @("ps", "status") } {
    Invoke-Compose @("ps")
  }
  "stop" {
    Invoke-Compose @("stop")
  }
  "down" {
    Invoke-Compose @("down")
  }
  "rebuild" {
    Invoke-ComposeStart @("up", "--build", "--force-recreate", "-d")
    Invoke-Compose @("ps")
  }
  "help" {
    Write-Usage
  }
}
