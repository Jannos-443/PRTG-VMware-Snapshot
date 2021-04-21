<#   
    .SYNOPSIS
    Monitors Snapshot Age/Size

    .DESCRIPTION
    Using VMware PowerCLI this Script checks VMware Snappshot Size and Age
    Exceptions can be made within this script by changing the variable $IgnoreScript. This way, the change applies to all PRTG sensors 
    based on this script. If exceptions have to be made on a per sensor level, the script parameter $IgnorePattern can be used.

    Copy this script to the PRTG probe EXEXML scripts folder (${env:ProgramFiles(x86)}\PRTG Network Monitor\Custom Sensors\EXEXML)
    and create a "EXE/Script Advanced. Choose this script from the dropdown and set at least:

    + Parameters: VCenter, User, Password
    + Scanning Interval: minimum 5 minutes

    .PARAMETER ViServer
    The Hostname of the VCenter Server

    .PARAMETER User
    Provide the VCenter Username

    .PARAMETER Password
    Provide the VCenter Password

    .PARAMETER IgnorePattern
    Regular expression to describe the VM Name for Example "Test" to exclude every VM with Test in the name

    Example: ^(DemoTestServer|DemoAusname2)$

    Example2: ^(Test123.*|Test555)$ excludes Test123, Test1234, Test12345 and Test555

    #https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions?view=powershell-7.1
    
    .PARAMETER WarningHours
    Warninglimit for Snapshot Age
    
    .PARAMETER ErrorHours
    Errorlimit for Snapshot Age

    .PARAMETER WarningSize
    Warninglimit for Snapshot Size

    .PARAMETER ErrorSize
    Errorlimit for Snapshot Size
    
    .EXAMPLE
    Sample call from PRTG EXE/Script Advanced
    PRTG-VMware-Snapshot.ps1 -ViServer '%VCenter%' -User '%Username%' -Password '%PW%'

    .NOTES
    This script is based on the sample by Paessler (https://kb.paessler.com/en/topic/67869-auto-starting-services) and debold (https://github.com/debold/PRTG-WindowsServices)

    Author:  Jannos-443
    https://github.com/Jannos-443/PRTG-VMware-Snapshot

#>
param(
    [string]$ViServer = '',
    [string]$User = '',
    [string]$Password = '',
    [string]$IgnorePattern = '', #VMs to ignore
    [int]$WarningHours = 24,
    [int]$ErrorHours = 48,
    [int]$WarningSize = 10,  #in GB
    [int]$ErrorSize = 20     #in GB
)

#Catch all unhandled Errors
trap{
    if($connected)
        {
        $null = Disconnect-VIServer -Server $ViServer -Confirm:$false -ErrorAction SilentlyContinue
        }
    $Output = "line:$($_.InvocationInfo.ScriptLineNumber.ToString()) char:$($_.InvocationInfo.OffsetInLine.ToString()) --- message: $($_.Exception.Message.ToString()) --- line: $($_.InvocationInfo.Line.ToString()) "
    $Output = $Output.Replace("<","")
    $Output = $Output.Replace(">","")
    Write-Output "<prtg>"
    Write-Output "<error>1</error>"
    Write-Output "<text>$Output</text>"
    Write-Output "</prtg>"
    Exit
}

#https://stackoverflow.com/questions/19055924/how-to-launch-64-bit-powershell-from-32-bit-cmd-exe
#############################################################################
#If Powershell is running the 32-bit version on a 64-bit machine, we 
#need to force powershell to run in 64-bit mode .
#############################################################################
if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    #Write-warning  "Y'arg Matey, we're off to 64-bit land....."
    if ($myInvocation.Line) {
        &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile $myInvocation.Line
    }else{
        &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile -file "$($myInvocation.InvocationName)" $args
    }
exit $lastexitcode
}

#############################################################################
#End
#############################################################################    

$connected = $false
$WarningVMs = ""
$ErrorVMs = ""

# Error if there's anything going on
$ErrorActionPreference = "Stop"


# Import VMware PowerCLI module
try {
    Import-Module "VMware.VimAutomation.Core" -ErrorAction Stop
} catch {
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>Error Loading VMware Powershell Module ($($_.Exception.Message))</text>"
    Write-Output "</prtg>"
    Exit
}

# Parameter empty = 999
# if you don´t need Size or Hours just leave it empty
if(($WarningHours -eq "") -and ($WarningHours -ne 0)){
    $WarningHours = 999
    }
if(($ErrorHours -eq "") -and ($ErrorHours -ne 0)){
    $ErrorHours = 999
    }
if(($WarningSize -eq "") -and ($WarningSize -ne 0)){
    $WarningSize = 999
    }
if(($ErrorSize -eq "") -and ($ErrorSize -ne 0)){
    $ErrorSize = 999
    }


# Ignore certificate warnings
Set-PowerCLIConfiguration -InvalidCertificateAction ignore -Confirm:$false | Out-Null

# Disable CEIP
Set-PowerCLIConfiguration -ParticipateInCeip $false -Scope User -Confirm:$false | Out-Null


# Connect to vCenter
try {
    Connect-VIServer -Server $ViServer -User $User -Password $Password
            
    $connected = $true
    }
 
catch
    {
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>Could not connect to vCenter server $ViServer. Error: $($_.Exception.Message)</text>"
    Write-Output "</prtg>"
    Exit
    }

# Get a list of all VMs
try {
    $VMs = Get-VM

} catch {
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>Could not Get-VM. Error: $($_.Exception.Message)</text>"
    Write-Output "</prtg>"
    Exit
}


# Get Snapshots from every VM
$AllSnaps = New-Object -TypeName "System.Collections.ArrayList"
foreach ($VM in $VMs) {
    $Snaps = Get-Snapshot -VM $VM -ErrorAction SilentlyContinue
    if ($Snaps -ne $null ) {
        # Save VM names for later use
        $null = $AllSnaps.Add($Snaps)
    }
}

#Filter Snapshots

# hardcoded list that applies to all hosts
$IgnoreScript = '^(TestIgnore)$' 

#Remove Ignored VMs
if ($IgnorePattern -ne "") {
    $AllSnaps = $AllSnaps | where {$_.VM -notmatch $IgnorePattern}  
}

if ($IgnoreScript -ne "") {
    $AllSnaps = $AllSnaps | where {$_.VM -notmatch $IgnoreScript}  
}

$WarningCount = 0
$ErrorCount = 0
$AllCount = $AllSnaps.Count

foreach ($Snap in $AllSnaps){
    if(($Snap.Size -ge $ErrorSize) -or ($Snap.Created -le (get-date).AddHours(-$ErrorHours)))
        {
        $ErrorVMs += "VM=$($Snap.VM) Created=$(Get-Date -Date $snap.Created -Format "yy.MM.dd-HH:mm") Size=$([math]::Round(($Snap.SizeGB),2))GB; "
        $ErrorCount +=1
        }
    elseif(($Snap.Size -ge $WarningSize) -or ($Snap.Created -le (get-date).AddHours(-$WarningHours)))
        {
        $WarningVMs  += "VM=$($Snap.VM) Created=$(Get-Date -Date $snap.Created -Format "yy.MM.dd-HH:mm") Size=$([math]::Round(($Snap.SizeGB),2))GB; " 
        $WarningCount +=1
        }
}


# Disconnect from vCenter
Disconnect-VIServer -Server $ViServer -Confirm:$false

$connected = $false

# Results
$xmlOutput = '<prtg>'
if ($ErrorCount -ge 1) {
    $xmlOutput = $xmlOutput + "<text>Error - $($ErrorVMs)</text>"
    }

if (($WarningCount -ge 1) -and ($ErrorCount -eq 0)){
    $xmlOutput = $xmlOutput + "<text>Warning - $($WarningVMs)</text>"
    } 

if(($WarningCount -eq 0) -and ($ErrorCount -eq 0)) {
    $xmlOutput = $xmlOutput + "<text>No Snapshots older $($WarningHours) hours or greater $($WarningSize)GB</text>"
}


$xmlOutput = $xmlOutput + "<result>
        <channel>Total Snapshots</channel>
        <value>$AllCount</value>
        <unit>Count</unit>
        </result>

        <result>
        <channel>Snapshot Error</channel>
        <value>$ErrorCount</value>
        <unit>Count</unit>
        <limitmode>1</limitmode>
        <LimitMaxError>0</LimitMaxError>
        </result>
        
        <result>
        <channel>Snapshot Warning</channel>
        <value>$WarningCount</value>
        <unit>Count</unit>
        <limitmode>1</limitmode>
        <LimitMaxWarning>0</LimitMaxWarning>
        </result>"   
        



$xmlOutput = $xmlOutput + "</prtg>"

$xmlOutput
