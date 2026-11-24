param(
  [Parameter(Mandatory = $true)]
  [string]$Version,

  [ValidateSet('amd64', 'arm64')]
  [string]$Arch = 'amd64',

  [string]$BundleDir = '',

  [string]$OutDir = 'dist'
)

$ErrorActionPreference = 'Stop'

if ($Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$') {
  throw 'Expected a numeric version with an optional prerelease suffix'
}

$flutterArch = if ($Arch -eq 'arm64') { 'arm64' } else { 'x64' }
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($BundleDir)) {
  $BundleDir = Join-Path $repoRoot "build/windows/$flutterArch/runner/Release"
}
if (-not (Test-Path -LiteralPath $BundleDir -PathType Container)) {
  throw "Missing Windows release bundle directory: $BundleDir"
}
$BundleDir = (Resolve-Path -LiteralPath $BundleDir).Path

foreach ($required in @('PortWeave.exe', 'FlClashCore.exe', 'FlClashHelperService.exe')) {
  $candidate = Join-Path $BundleDir $required
  if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
    throw "Missing required binary: $candidate"
  }
}

$appExe = Join-Path $BundleDir 'PortWeave.exe'
$versionInfo = (Get-Item -LiteralPath $appExe).VersionInfo
if ($versionInfo.ProductName -ne 'PortWeave' -or $versionInfo.CompanyName -ne 'io.github.minggle') {
  throw "Unexpected PortWeave.exe identity (ProductName='$($versionInfo.ProductName)', CompanyName='$($versionInfo.CompanyName)'); refusing to package"
}

$makeConfigPath = Join-Path $repoRoot 'windows/packaging/exe/make_config.yaml'
if (-not (Test-Path -LiteralPath $makeConfigPath -PathType Leaf)) {
  throw "Missing Inno Setup config: $makeConfigPath"
}

$config = @{}
foreach ($rawLine in Get-Content -LiteralPath $makeConfigPath) {
  $line = $rawLine.Trim()
  if ([string]::IsNullOrEmpty($line) -or $line.StartsWith('#')) { continue }
  $parts = $line -split ':', 2
  if ($parts.Count -ne 2) { continue }
  $key = $parts[0].Trim()
  $value = $parts[1].Trim().Trim("'`"")
  $config[$key] = $value
}

if ($config['app_name'] -ne 'PortWeave' -or $config['display_name'] -ne 'PortWeave' -or $config['executable_name'] -ne 'PortWeave.exe') {
  throw 'Unexpected windows/packaging/exe/make_config.yaml identity; refusing to package'
}

function Find-Iscc {
  $candidates = @()
  if (-not [string]::IsNullOrWhiteSpace($env:INNO_SETUP_PATH)) {
    $candidates += (Join-Path $env:INNO_SETUP_PATH 'ISCC.exe')
  }
  $candidates += 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
  $candidates += 'C:\Program Files\Inno Setup 6\ISCC.exe'
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return $candidate
    }
  }
  $cmd = Get-Command iscc -ErrorAction SilentlyContinue
  if ($null -ne $cmd) {
    return $cmd.Source
  }
  throw 'ISCC.exe not found; install Inno Setup 6 or set INNO_SETUP_PATH'
}

$iscc = Find-Iscc

if (-not (Test-Path -LiteralPath $OutDir)) {
  New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}
$OutDir = (Resolve-Path -LiteralPath $OutDir).Path

$zipName = "PortWeave-$Version-windows-$Arch.zip"
$zipPath = Join-Path $OutDir $zipName
if (Test-Path -LiteralPath $zipPath) {
  Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -Path (Join-Path $BundleDir '*') -DestinationPath $zipPath -Force

$setupBaseName = "PortWeave-$Version-windows-$Arch-setup"
$setupName = "$setupBaseName.exe"
$setupPath = Join-Path $OutDir $setupName
if (Test-Path -LiteralPath $setupPath) {
  Remove-Item -LiteralPath $setupPath -Force
}

$stageDirName = "${setupBaseName}_exe"
$stageDir = Join-Path $OutDir $stageDirName
$issPath = Join-Path $OutDir "$setupBaseName.iss"
$templatePath = Join-Path $repoRoot "windows/packaging/exe/$($config['script_template'])"
if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
  throw "Missing Inno Setup template: $templatePath"
}

try {
  if (Test-Path -LiteralPath $stageDir) {
    Remove-Item -LiteralPath $stageDir -Recurse -Force
  }
  New-Item -ItemType Directory -Path $stageDir -Force | Out-Null
  Copy-Item -Path (Join-Path $BundleDir '*') -Destination $stageDir -Recurse -Force

  $installDirName = if ($config.ContainsKey('install_dir_name') -and -not [string]::IsNullOrWhiteSpace($config['install_dir_name'])) {
    $config['install_dir_name']
  } else {
    "{autopf64}\$($config['app_name'])"
  }

  $variables = @{
    'APP_ID'                      = $config['app_id']
    'APP_NAME'                    = $config['app_name']
    'APP_VERSION'                 = $Version
    'DISPLAY_NAME'                = $config['display_name']
    'PUBLISHER_NAME'              = $config['publisher']
    'PUBLISHER_URL'               = $config['publisher_url']
    'INSTALL_DIR_NAME'            = $installDirName
    'EXECUTABLE_NAME'             = $config['executable_name']
    'OUTPUT_BASE_FILENAME'        = $setupBaseName
    'SOURCE_DIR'                  = $stageDirName
    'SETUP_ICON_FILE'             = (Join-Path $repoRoot $config['setup_icon_file'])
    'CHINESE_SIMPLIFIED_MESSAGES' = (Join-Path $repoRoot 'windows\packaging\exe\ChineseSimplified.isl')
    'ARCH'                        = $flutterArch
  }

  $template = [System.IO.File]::ReadAllText($templatePath, [System.Text.Encoding]::UTF8)
  $rendered = [System.Text.RegularExpressions.Regex]::Replace(
    $template,
    '\{\{([A-Z_]+)\}\}',
    {
      param($match)
      $name = $match.Groups[1].Value
      if (-not $variables.ContainsKey($name) -or $null -eq $variables[$name]) {
        throw "inno_setup.iss uses {{$name}}, which has no value"
      }
      return $variables[$name]
    }
  )
  if ($rendered.Contains('{%')) {
    throw 'inno_setup.iss still holds a {% %} tag'
  }

  [System.IO.File]::WriteAllText($issPath, $rendered, [System.Text.UTF8Encoding]::new($true))

  & $iscc $issPath
  if ($LASTEXITCODE -ne 0) {
    throw "ISCC.exe failed with exit code $LASTEXITCODE"
  }
  if (-not (Test-Path -LiteralPath $setupPath -PathType Leaf)) {
    throw "Expected installer was not produced: $setupPath"
  }
} finally {
  if (Test-Path -LiteralPath $stageDir) {
    Remove-Item -LiteralPath $stageDir -Recurse -Force
  }
  if (Test-Path -LiteralPath $issPath) {
    Remove-Item -LiteralPath $issPath -Force
  }
}

$checksumLines = @()
foreach ($assetName in (@($setupName, $zipName) | Sort-Object)) {
  $assetPath = Join-Path $OutDir $assetName
  $hash = (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $checksumLines += "$hash  $assetName"
}
$checksumPath = Join-Path $OutDir "SHA256SUMS-windows-$Arch"
[System.IO.File]::WriteAllText(
  $checksumPath,
  ($checksumLines -join "`n") + "`n",
  [System.Text.UTF8Encoding]::new($false)
)
