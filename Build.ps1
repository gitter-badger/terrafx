Param(
  [string] $assemblyVersion = "0.1",
  [string] $buildVersion = "0.0",
  [string] $configuration = "Debug",
  [string] $informationalVersion = "alpha",
  [string] $msbuildVersion = "14.0",
  [string] $nugetVersion = "3.4.0-rc",
  [switch] $skipBuild,
  [switch] $skipRestore,
  [string] $target = "Build"
)

function Create-Directory([string[]] $path) {
  if (!(Test-Path -path $path)) {
    New-Item -path $path -force -itemType "Directory" | Out-Null
  }
}

function Download-File([string] $address, [string] $fileName) {
  $webClient = New-Object -typeName "System.Net.WebClient"
  $webClient.DownloadFile($address, $fileName)
}

function Get-ProductVersion([string[]] $path) {
  if (!(Test-Path -path $path)) {
    return ""
  }

  $item = Get-Item -path $path
  return $item.VersionInfo.ProductVersion
}

function Get-RegistryValue([string] $keyName, [string] $valueName) {
  $registryKey = Get-ItemProperty -path $keyName
  return $registryKey.$valueName
}

function Locate-ArtifactsPath {
  $scriptPath = Locate-ScriptPath
  $artifactsPath = Join-Path -path $scriptPath -ChildPath ".artifacts\"

  Create-Directory -path $artifactsPath
  return Resolve-Path -path $artifactsPath
}

function Locate-MSBuild {
  $msbuildPath = Locate-MSBuildPath
  $msbuild = Join-Path -path $msbuildPath -childPath "MSBuild.exe"

  if (!(Test-Path -path $msbuild)) {
    throw "The specified MSBuild version ($msbuildVersion) could not be located."
  }

  return Resolve-Path -path $msbuild
}

function Locate-MSBuildLogPath {
  $artifactsPath = Locate-ArtifactsPath
  $msbuildLogPath = Join-Path -path $artifactsPath -ChildPath "$configuration\Build\"

  Create-Directory -path $msbuildLogPath
  return Resolve-Path -path $msbuildLogPath
}

function Locate-MSBuildPath {
  $msbuildVersionPath = Locate-MSBuildVersionPath
  $msbuildPath = Get-RegistryValue -keyName $msbuildVersionPath -valueName "MSBuildToolsPath"
  return Resolve-Path -path $msbuildPath
}

function Locate-MSBuildVersionPath {
  $msbuildVersionPath = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\MSBuild\ToolsVersions\$msbuildVersion"

  if (!(Test-Path -path $msbuildVersionPath)) {
    $msbuildVersionPath = "HKLM:\SOFTWARE\Microsoft\MSBuild\ToolsVersions\$msbuildVersion"

    if (!(Test-Path -path $msbuildVersionPath)) {
      throw "The specified MSBuild version ($msbuildVersion) could not be located."
    }
  }

  return Resolve-Path -path $msbuildVersionPath
}

function Locate-NuGet {
  $scriptPath = Locate-ScriptPath
  $nuget = Join-Path -path $scriptPath -childPath "nuget.exe"

  if (Test-Path -path $nuget) {
    $currentVersion = Get-ProductVersion -path $nuget

    if ($currentVersion.StartsWith($nugetVersion)) {
      return Resolve-Path -path $nuget
    }

    Write-Host -object "The located version of NuGet ($currentVersion) is out of date. The specified version ($nugetVersion) will be downloaded instead."
    Remove-Item -path $nuget | Out-Null
  }

  Download-File -address "https://dist.nuget.org/win-x86-commandline/v$nugetVersion/nuget.exe" -fileName $nuget

  if (!(Test-Path -path $nuget)) {
    throw "The specified NuGet version ($nugetVersion) could not be downloaded."
  }

  return Resolve-Path -path $nuget
}

function Locate-NuGetConfig {
  $scriptPath = Locate-ScriptPath
  $nugetConfig = Join-Path -path $scriptPath -childPath "nuget.config"
  return Resolve-Path -path $nugetConfig
}

function Locate-PackagesPath {
  $scriptPath = Locate-ScriptPath
  $packagesPath = Join-Path -path $scriptPath -childPath ".packages\"

  Create-Directory -path $packagesPath
  return Resolve-Path -path $packagesPath
}

function Locate-ScriptPath {
  $myInvocation = Get-Variable -name "MyInvocation" -scope "Script"
  $scriptPath = Split-Path -path $myInvocation.Value.MyCommand.Definition -parent
  return Resolve-Path -path $scriptPath
}

function Locate-Solution {
  $scriptPath = Locate-ScriptPath
  $solution = Join-Path -path $scriptPath -childPath "TerraFX.sln"
  return Resolve-Path -path $solution
}

function Perform-Build {
  if ($skipBuild) {
    Write-Host -object "Skipping build..."
    return
  }

  $artifactsPath = Locate-ArtifactsPath
  $msbuild = Locate-MSBuild
  $msbuildLogPath = Locate-MSBuildLogPath
  $solution = Locate-Solution

  $msbuildSummaryLog = Join-Path -path $msbuildLogPath -childPath "MSBuild.log"
  $msbuildWarningLog = Join-Path -path $msbuildLogPath -childPath "MSBuild.wrn"
  $msbuildFailureLog = Join-Path -path $msbuildLogPath -childPath "MSBuild.err"

  Write-Host -object "Starting build..."
  & $msbuild /t:$target /p:ArtifactsPath=$artifactsPath /p:AssemblyVersion=$assemblyVersion /p:BuildVersion=$buildVersion /p:Configuration=$configuration /p:InformationalVersion=$informationalVersion /m /tv:$msbuildVersion /v:n /flp1:Summary`;Verbosity=diagnostic`;Encoding=UTF-8`;LogFile=$msbuildSummaryLog /flp2:WarningsOnly`;Verbosity=diagnostic`;Encoding=UTF-8`;LogFile=$msbuildWarningLog /flp3:ErrorsOnly`;Verbosity=diagnostic`;Encoding=UTF-8`;LogFile=$msbuildFailureLog /nr:false $solution

  if ($lastExitCode -ne 0) {
    throw "The build failed with an exit code of '$lastExitCode'."
  }

  Write-Host -object "The build completed successfully." -foregroundColor Green
}

function Perform-Restore {
  if ($skipRestore) {
    Write-Host -object "Skipping restore..."
    return
  }

  $nuget = Locate-NuGet
  $nugetConfig = Locate-NuGetConfig
  $packagesPath = Locate-PackagesPath
  $solution = Locate-Solution

  Write-Host -object "Starting restore..."
  & $nuget restore -packagesDirectory $packagesPath -msbuildVersion $msbuildVersion -verbosity normal -nonInteractive -configFile $nugetConfig $solution

  if ($lastExitCode -ne 0) {
    throw "The restore failed with an exit code of '$lastExitCode'."
  }

  Write-Host -object "The restore completed successfully." -foregroundColor Green
}

Perform-Restore
Perform-Build
