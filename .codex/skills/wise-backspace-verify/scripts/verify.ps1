param(
  [string]$Repo,
  [string]$Nvim = $env:NVIM_BIN
)

$ErrorActionPreference = 'Stop'

function Resolve-Repo {
  param([string]$Requested)

  if ($Requested) {
    return (Resolve-Path -LiteralPath $Requested).Path
  }

  return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..\..')).Path
}

function Resolve-Nvim {
  param([string]$Requested)

  if ($Requested) {
    return (Resolve-Path -LiteralPath $Requested).Path
  }

  $command = Get-Command nvim -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $candidates = @(
    (Join-Path $env:LOCALAPPDATA 'mise\installs\neovim\0.12.2\bin\nvim.exe'),
    (Join-Path $env:LOCALAPPDATA 'mise\shims\nvim.exe'),
    'C:\Program Files\Neovim\bin\nvim.exe'
  )

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  throw 'nvim executable was not found. Set NVIM_BIN or pass -Nvim.'
}

function Assert-RepoFile {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing required file: $Path"
  }
}

function Assert-LfOnly {
  param([string]$Root)

  $extensions = @('.lua', '.md', '.vim', '.ps1', '.sh', '.yml', '.yaml', '.json', '.toml')
  $bad = @()
  $gitSegment = [IO.Path]::DirectorySeparatorChar + '.git' + [IO.Path]::DirectorySeparatorChar

  Get-ChildItem -LiteralPath $Root -Recurse -File -Force |
    Where-Object { $_.FullName -notlike "*$gitSegment*" } |
    Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
    ForEach-Object {
      $bytes = [IO.File]::ReadAllBytes($_.FullName)
      for ($i = 0; $i -lt $bytes.Length - 1; $i++) {
        if ($bytes[$i] -eq 13 -and $bytes[$i + 1] -eq 10) {
          $bad += $_.FullName
          break
        }
      }
    }

  if ($bad.Count -gt 0) {
    throw "CRLF line endings found:`n$($bad -join "`n")"
  }
}

$repoRoot = Resolve-Repo -Requested $Repo
$nvimExe = Resolve-Nvim -Requested $Nvim

Assert-RepoFile (Join-Path $repoRoot 'lua\wise-backspace\init.lua')
Assert-RepoFile (Join-Path $repoRoot 'lua\wise-backspace\indent.lua')
Assert-RepoFile (Join-Path $repoRoot 'tests\minimal_init.lua')
Assert-RepoFile (Join-Path $repoRoot 'tests\run.lua')
Assert-RepoFile (Join-Path $repoRoot '.gitattributes')
Assert-RepoFile (Join-Path $repoRoot '.gitignore')
Assert-RepoFile (Join-Path $repoRoot 'AGENTS.md')

Write-Host "nvim: $nvimExe"
Write-Host 'checking LF line endings'
Assert-LfOnly -Root $repoRoot

$logDir = Join-Path $repoRoot '.tests'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$env:NVIM_LOG_FILE = Join-Path $logDir 'nvim.log'

Write-Host 'running headless Neovim tests'
& $nvimExe --headless --clean -u (Join-Path $repoRoot 'tests\minimal_init.lua') -l (Join-Path $repoRoot 'tests\run.lua')
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host 'running git diff --check'
git -C $repoRoot diff --check -- .
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host 'git status --short'
git -C $repoRoot status --short
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host 'verification passed'
