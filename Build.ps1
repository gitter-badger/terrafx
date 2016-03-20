Param(
  [string] $assemblyVersion = "0.1",
  [string] $buildVersion = "0.0",
  [string] $configuration = "Debug",
  [string] $informationalVersion = "alpha",
  [string] $msbuildVersion = "14.0",
  [switch] $skipBuild,
  [string] $target = "Build"
)

function Create-Directory([string[]] $path) {
  if (!(Test-Path -path $path)) {
    New-Item -path $path -force -itemType "Directory" | Out-Null
  }
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

Perform-Build
