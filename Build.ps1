Param(
  [string] $assemblyVersion = "0.1",
  [string] $buildVersion = "0.0",
  [string] $configuration = "Debug",
  [string] $gitLinkVersion =  "2.2.0",
  [string] $informationalVersion = "alpha",
  [string] $msbuildVersion = "14.0",
  [string] $nugetVersion = "3.4.0-rc",
  [string] $nunitVersion = "3.2.0",
  [switch] $skipBuild,
  [switch] $skipRestore,
  [switch] $skipSourceLink,
  [switch] $skipTest,
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

function Install-Package([string] $packageName, [string] $packageVersion) {
  $packagesPath = Locate-PackagesPath
  $nuget = Locate-NuGet
  $nugetConfig = Locate-NuGetConfig

  Write-Host -object "Installing $packageName.$packageVersion"
  & $nuget install -outputDirectory $packagesPath -version $packageVersion -preRelease -verbosity normal -nonInteractive -configFile $nugetConfig $packageName | Out-Null

  if ($lastExitCode -ne 0) {
    throw "The restore failed with an exit code of '$lastExitCode'."
  }
}

function Locate-ArtifactsPath {
  $scriptPath = Locate-ScriptPath
  $artifactsPath = Join-Path -path $scriptPath -ChildPath ".artifacts\"

  Create-Directory -path $artifactsPath
  return Resolve-Path -path $artifactsPath
}

function Locate-GitLink {
  $gitLinkPath = Locate-GitLinkPath
  $gitLink = Join-Path -path $gitLinkPath -childPath "GitLink.exe"

  if (Test-Path -path $gitLink) {
    return Resolve-Path -path $gitLink
  }

  Install-Package -packageName "GitLink" -packageVersion $gitLinkVersion

  if (!(Test-Path -path $gitLink)) {
    throw "The specified GitLink version ($gitVersion) could not be installed."
  }

  return Resolve-Path -path $gitLink
}

function Locate-GitLinkLogPath {
  $artifactsPath = Locate-ArtifactsPath
  $gitLinkLogPath = Join-Path -path $artifactsPath -ChildPath "$configuration\SourceLink\"

  Create-Directory -path $gitLinkLogPath
  return Resolve-Path -path $gitLinkLogPath
}

function Locate-GitLinkPath {
  $packagesPath = Locate-PackagesPath
  $gitLinkPath = Join-Path -path $packagesPath -childPath "GitLink.$gitLinkVersion\lib\net45\"

  Create-Directory -path $gitLinkPath
  return Resolve-Path -path $gitLinkPath
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

function Locate-NUnit {
  $nunitPath = Locate-NUnitPath
  $nunit = Join-Path -path $nunitPath -childPath "nunit3-console.exe"

  if (Test-Path -path $nunit) {
    return Resolve-Path -path $nunit
  }

  Install-Package -packageName "NUnit.Runners" -packageVersion $nunitVersion

  if (!(Test-Path -path $nunit)) {
    throw "The specified NUnit version ($nunitVersion) could not be installed."
  }

  return Resolve-Path -path $nunit
}

function Locate-NUnitPath {
  $packagesPath = Locate-PackagesPath
  $nunitPath = Join-Path -path $packagesPath -childPath "NUnit.ConsoleRunner.$nunitVersion\tools\"

  Create-Directory -path $nunitPath
  return Resolve-Path -path $nunitPath
}

function Locate-NUnitLogPath {
  $artifactsPath = Locate-ArtifactsPath
  $nunitLogPath = Join-Path -path $artifactsPath -ChildPath "$configuration\Test\"

  Create-Directory -path $nunitLogPath
  return Resolve-Path -path $nunitLogPath
}

function Locate-NUnitProject {
  $scriptPath = Locate-ScriptPath
  $nunitProject = Join-Path -path $scriptPath -childPath "TerraFX.nunit"
  return Resolve-Path -path $nunitProject
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

function Perform-SourceLink {
  if ($skipSourceLink) {
    Write-Host -object "Skipping source link..."
    return
  }

  $gitLink = Locate-GitLink
  $gitLinkLogPath = Locate-GitLinkLogPath
  $scriptPath = Locate-ScriptPath
  $solution = Locate-Solution

  $gitLinkSummaryLog = Join-Path -path $gitLinkLogPath -childPath "GitLink.log"

  Write-Host -object "Starting source link..."
  & $gitLink $scriptPath -f $solution -c $configuration -l $gitLinkSummaryLog

  if ($lastExitCode -ne 0) {
    throw "The source link failed with an exit code of '$lastExitCode'."
  }

  Write-Host -object "The source link completed successfully." -foregroundColor Green
}

function Perform-Test {
  if ($skipTest) {
    Write-Host -object "Skipping test..."
    return
  }

  $nunit = Locate-NUnit
  $nunitLogPath = Locate-NUnitLogPath
  $nunitProject = Locate-NUnitProject

  $nunitSummaryLog = Join-Path -path $nunitLogPath -childPath "NUnit.log"
  $nunitFailureLog = Join-Path -path $nunitLogPath -childPath "NUnit.err"
  $nunitResultLog = Join-Path -path $nunitLogPath -childPath "NUnit.xml"

  Write-Host -object "Starting test..."
  & $nunit $nunitProject --work=$nunitLogPath --output=$nunitSummaryLog --err=$nunitFailureLog --full --result=$nunitResultLog --labels=All --verbose --config=$configuration

  if ($lastExitCode -ne 0) {
    throw "The test failed with an exit code of '$lastExitCode'."
  }

  Write-Host -object "The test completed successfully." -foregroundColor Green
}

Perform-Restore
Perform-Build
Perform-SourceLink
Perform-Test
