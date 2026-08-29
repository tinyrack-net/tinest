param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^v\d+\.\d+\.\d+$')]
  [string]$ReleaseTag
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:WINGET_CREATE_GITHUB_TOKEN)) {
  throw 'WINGET_TOKEN repository secret is required for WinGet publishing.'
}

$repository = if ([string]::IsNullOrWhiteSpace($env:GITHUB_REPOSITORY)) {
  'tinyrack-net/tinest'
} else {
  $env:GITHUB_REPOSITORY
}
$version = $ReleaseTag -replace '^v', ''
$downloadRoot = "https://github.com/$repository/releases/download/$ReleaseTag"
$releaseNotesUrl = "https://github.com/$repository/releases/tag/$ReleaseTag"

Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe

function Test-WinGetPackage {
  param([Parameter(Mandatory = $true)][string]$PackageIdentifier)

  $segments = $PackageIdentifier.Split('.')
  $manifestPath = "manifests/$($segments[0][0].ToString().ToLowerInvariant())/$($segments -join '/')"
  $uri = "https://api.github.com/repos/microsoft/winget-pkgs/contents/$manifestPath"
  $response = Invoke-WebRequest -Uri $uri -SkipHttpErrorCheck
  if ($response.StatusCode -eq 200) {
    return $true
  }
  if ($response.StatusCode -eq 404) {
    return $false
  }
  throw "WinGet package lookup failed for $PackageIdentifier with HTTP $($response.StatusCode)."
}

function Submit-InitialManifest {
  param(
    [Parameter(Mandatory = $true)][string]$PackageIdentifier,
    [Parameter(Mandatory = $true)][string]$AssetName
  )

  $templateRoot = Join-Path '.github/winget/initial-manifests' $PackageIdentifier
  $manifestRoot = Join-Path $env:RUNNER_TEMP $PackageIdentifier
  Copy-Item -Recurse -Force $templateRoot $manifestRoot

  $assetPath = Join-Path $env:RUNNER_TEMP $AssetName
  Invoke-WebRequest "$downloadRoot/$AssetName" -OutFile $assetPath
  $installerSha256 = (Get-FileHash -Algorithm SHA256 $assetPath).Hash

  Get-ChildItem $manifestRoot -Filter '*.yaml' | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $content = $content.Replace('__VERSION__', $version)
    $content = $content.Replace('__DOWNLOAD_ROOT__', $downloadRoot)
    $content = $content.Replace('__RELEASE_NOTES_URL__', $releaseNotesUrl)
    $content = $content.Replace('__INSTALLER_SHA256__', $installerSha256)
    Set-Content -Path $_.FullName -Value $content -NoNewline
  }

  .\wingetcreate.exe submit $manifestRoot --no-open
  if ($LASTEXITCODE -ne 0) {
    throw "Initial WinGet submission failed for $PackageIdentifier."
  }
}

function Publish-WinGetPackage {
  param(
    [Parameter(Mandatory = $true)][string]$PackageIdentifier,
    [Parameter(Mandatory = $true)][string]$AssetName
  )

  if (Test-WinGetPackage $PackageIdentifier) {
    .\wingetcreate.exe update $PackageIdentifier `
      --version $version `
      --urls "$downloadRoot/$AssetName|x64" `
      --release-notes-url $releaseNotesUrl `
      --submit `
      --no-open
    if ($LASTEXITCODE -ne 0) {
      throw "WinGet update failed for $PackageIdentifier."
    }
    return
  }

  Submit-InitialManifest $PackageIdentifier $AssetName
}

Publish-WinGetPackage 'Tinyrack.Tinest' 'Tinest-setup-win-x64.exe'
Publish-WinGetPackage 'Tinyrack.TinestCLI' 'tinest-cli-windows-x64.zip'
