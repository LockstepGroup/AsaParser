[CmdletBinding()]
Param (
    [Parameter(Mandatory=$False,Position=0)]
	[switch]$PushToStrap
)

function ZipFiles {
    [CmdletBinding()]
    Param (
    	[Parameter(Mandatory=$True,Position=0)]
		[string]$ZipFilePath,

        [Parameter(ParameterSetName="Directory",Mandatory=$True,Position=1)]
        [string]$SourceDir,

        [Parameter(ParameterSetName="Files",Mandatory=$True,Position=1)]
        [Array]$SourceFiles,

        [Parameter(Mandatory=$False)]
        [switch]$Force

    )
    Add-Type -Assembly System.IO.Compression.FileSystem
    $CompressionLevel = [System.IO.Compression.CompressionLevel]::Optimal

    if (Test-Path $ZipFilePath) {
        if ($Force) {
            $Delete = Remove-Item $ZipFilePath
        } else {
            Throw "$ZipFilePath exists, use -Force to replace"
        }
    }

    if ($SourceFiles) {
        $TempZipFolder = 'newzip'
        $TempZipFullPath = "$($env:temp)\$TempZipFolder"
        $CreateFolder = New-Item -Path $env:temp -Name $TempZipFolder -ItemType Directory
        $Copy = Copy-Item $SourceFiles -Destination $TempZipFullPath
        $SourceDir = $TempZipFullPath
    }

    [System.IO.Compression.ZipFile]::CreateFromDirectory($SourceDir,$ZipFilePath, $CompressionLevel, $false)

    $Cleanup = Remove-Item $TempZipFullPath -Recurse
}


$ScriptPath = Split-Path $($MyInvocation.MyCommand).Path
$ModuleName = Split-Path $ScriptPath -Leaf

$SourceDirectory = "src"
$SourcePath      = $ScriptPath + "\" + $SourceDirectory
$CmdletPath      = $SourcePath + "\" + "cmdlets"
$HelperPath      = $SourcePath + "\" + "helpers"
$CsPath          = $SourcePath + "\" + "cs"
$OutputFile      = $ScriptPath + "\" + "$ModuleName.psm1"
$ManifestFile    = $ScriptPath + "\" + "$ModuleName.psd1"
$DllFile         = $ScriptPath + "\" + "$ModuleName.dll"
$CsOutputFile    = $ScriptPath + "\" + "$ModuleName.cs"

###############################################################################
# Create Manifest
$ManifestParams = @{ Path = $ManifestFile
                     ModuleVersion = '1.0'
                     RequiredAssemblies = @("$ModuleName.dll",'System.Web')
                     Author             = 'Brian Addicks'
                     RootModule         = "$ModuleName.psm1"
                     PowerShellVersion  = '4.0' 
                     RequiredModules    = @('ipv4math')}

New-ModuleManifest @ManifestParams

###############################################################################
# 

$CmdletHeader = @'
###############################################################################
## Start Powershell Cmdlets
###############################################################################


'@

$HelperFunctionHeader = @'
###############################################################################
## Start Helper Functions
###############################################################################


'@

$Footer = @'
###############################################################################
## Export Cmdlets
###############################################################################

Export-ModuleMember *-*
'@

$FunctionHeader = @'
###############################################################################
# 
'@

###############################################################################
# Start Output

$CsOutput  = ""

###############################################################################
# Add C-Sharp

$AssemblyRx       = [regex] '^using\ .+?;'
$NameSpaceStartRx = [regex] "namespace $ModuleName {"
$NameSpaceStopRx  = [regex] '^}$'

$Assemblies    = @()
$CSharpContent = @()

$c = 0
foreach ($f in $(ls $CsPath)) {
    foreach ($l in (gc $f.FullName)) {
        $AssemblyMatch       = $AssemblyRx.Match($l)
        $NameSpaceStartMatch = $NameSpaceStartRx.Match($l)
        $NameSpaceStopMatch  = $NameSpaceStopRx.Match($l)

        if ($AssemblyMatch.Success) {
            $Assemblies += $l
            continue
        }

        if ($NameSpaceStartMatch.Success) {
            $AddContent = $true
            continue
        }

        if ($NameSpaceStopMatch.Success) {
            $AddContent = $false
            continue
        }

        if ($AddContent) {
            $CSharpContent += $l
        }
    }
}

#$Assemblies | Select -Unique | sort -Descending

$CSharpOutput  = $Assemblies | Select -Unique | sort -Descending
$CSharpOutput += "namespace $ModuleName {"
$CSharpOutput += $CSharpContent
$CSharpOutput += '}'

$CsOutput += [string]::join("`n",$CSharpOutput)
$CsOutput | Out-File $CsOutputFile -Force


Add-Type -ReferencedAssemblies @(
	([System.Reflection.Assembly]::LoadWithPartialName("System.Xml")).Location,
	([System.Reflection.Assembly]::LoadWithPartialName("System.Web")).Location,
	([System.Reflection.Assembly]::LoadWithPartialName("System.Xml.Linq")).Location
	) -OutputAssembly $DllFile -OutputType Library -TypeDefinition $CsOutput

###############################################################################
# Add Cmdlets

$Output = $CmdletHeader

foreach ($l in $(ls $CmdletPath -exclude "*.Tests.*")) {
    $Contents  = gc $l.FullName
    Write-Verbose $l.FullName
    $Output   += $FunctionHeader
    $Output   += $l.BaseName
    $Output   += "`r`n`r`n"
    $Output   += [string]::join("`n",$Contents)
    $Output   += "`r`n`r`n"
}


###############################################################################
# Add Helpers

$Output += $HelperFunctionHeader

foreach ($l in $(ls $HelperPath)) {
    $Contents  = gc $l.FullName
    $Output   += $FunctionHeader
    $Output   += $l.BaseName
    $Output   += "`r`n`r`n"
    $Output   += [string]::join("`n",$Contents)
    $Output   += "`r`n`r`n"
}

###############################################################################
# Add Footer

$Output += $Footer

###############################################################################
# Output File

$Output | Out-File $OutputFile -Force

###############################################################################
# Import Module and Run Tests

$ImportModule = ipmo .\*.psd1
$ImportPester = ipmo Pester

#Initialize some variables, move to the project root
if ($ENV:APPVEYOR_BUILD_FOLDER) {
    # Running in AppVeyor
    $ProjectRoot = $ENV:APPVEYOR_BUILD_FOLDER
} else {
    $ProjectRoot = $ScriptPath
}

$PSVersion = $PSVersionTable.PSVersion.Major
$TestFile = "TestResultsPS$PSVersion.xml"
Set-Location $ProjectRoot

# Run Pester
Invoke-Pester -Path "$ProjectRoot\" -OutputFormat NUnitXml -OutputFile "$ProjectRoot\$TestFile" -PassThru | Export-Clixml -Path "$ProjectRoot\PesterResults$PSVersion.xml"

#Show status...
$AllFiles = Get-ChildItem -Path $ProjectRoot\*Results*.xml | Select -ExpandProperty FullName
"`n`tSTATUS: Finalizing results`n"
"COLLATING FILES:`n$($AllFiles | Out-String)"

#What failed?
$Results = @( Get-ChildItem -Path "$ProjectRoot\PesterResults*.xml" | Import-Clixml )

$FailedCount = $Results |
    Select -ExpandProperty FailedCount |
    Measure-Object -Sum |
    Select -ExpandProperty Sum

if ($FailedCount -gt 0) {

    $FailedItems = $Results |
        Select -ExpandProperty TestResult |
        Where {$_.Passed -notlike $True}

    "FAILED TESTS SUMMARY:`n"
    $FailedItems | ForEach-Object {
        $Test = $_
        [pscustomobject]@{
            Describe = $Test.Describe
            Context = $Test.Context
            Name = "It $($Test.Name)"
            Result = $Test.Result
        }
    } |
        Sort Describe, Context, Name, Result |
        Format-List

    throw "$FailedCount tests failed."
}

###############################################################################
# Zip and push to strap

if ($PushToStrap) {
    $FilesToZip = ls "$PSScriptRoot\$ModuleName*" -Exclude *.zip,*.cs
    $CreateZip = ZipFiles -ZipFilePath "$PSScriptRoot\$ModuleName.zip" -SourceFiles $FilesToZip -Force
    $StageFolder = "\\vmware-host\Shared Folders\Dropbox\strap\stages\$ModuleName\"
    if (!(Test-Path $StageFolder)) { $CreateStage = mkdir $StageFolder }
    $Copy = Copy-Item "$PSScriptRoot\$ModuleName.zip" $StageFolder -Force
}