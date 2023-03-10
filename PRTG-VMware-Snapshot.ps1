<#   
    .SYNOPSIS
    Monitors Snapshot Age/Size

    .DESCRIPTION
    Using VMware PowerCLI this Script checks VMware Snappshot Size and Age
    Exceptions can be made within this script by changing the variable $IgnoreScript. This way, the change applies to all PRTG sensors 
    based on this script. If exceptions have to be made on a per sensor level, the script parameter $ExcludeVMName can be used.

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
    
    .PARAMETER WarningHours
    Warninglimit for Snapshot Age
    
    .PARAMETER ErrorHours
    Errorlimit for Snapshot Age

    .PARAMETER WarningSize
    Warninglimit for Snapshot Size

    .PARAMETER ErrorSize
    Errorlimit for Snapshot Size

    .PARAMETER ExcludeVMName
    Regular expression to describe the VM Name for Example "Test" to exclude every VM with Test in the name

    Example: ^(DemoTestServer|Demo2-VM)$

    Example2: ^(Test123.*|Test555)$ excludes Test123, Test1234, Test12345 and Test555

    #https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions?view=powershell-7.1

    .PARAMETER ExcludeFolder
    Regular expression to describe a VMWare Folder to exclude

    .PARAMETER ExcludeRessource
    Regular expression to describe a VMWare Ressource to exclude.

    .PARAMETER ExcludeVMHost
    Regular expression to describe a VMWare VMHost to exclude. (maybe FQDN required)

    .PARAMETER ExcludeSnapDescription
    Regular expression to describe a VMWare Snapshot Description to exclude.

    .PARAMETER ExcludeSnapName
    Regular expression to describe a VMWare Snapshot Name to exclude.

    .PARAMETER IncludeVMName
    Regular expression to describe a VMWare Folder to Include

    .PARAMETER IncludeFolder
    Regular expression to describe a VMWare Folder to Include

    .PARAMETER IncludeRessource
    Regular expression to describe a VMWare Ressource to Include.

    .PARAMETER IncludeVMHost
    Regular expression to describe a VMWare VMHost to Include. (maybe FQDN required)

    .PARAMETER IncludeSnapDescription
    Regular expression to describe a VMWare Snapshot Description to Include.

    .PARAMETER IncludeSnapName
    Regular expression to describe a VMWare Snapshot Name to Include.

    .EXAMPLE
    Sample call from PRTG EXE/Script Advanced
    PRTG-VMware-Snapshot.ps1 -ViServer '%VCenter%' -User '%Username%' -Password '%PW%' -ExcludeVMName '^(TestVM.*)$'

    .NOTES
    This script is based on the sample by Paessler (https://kb.paessler.com/en/topic/67869-auto-starting-services) and debold (https://github.com/debold/PRTG-WindowsServices)

    Author:  Jannos-443
    https://github.com/Jannos-443/PRTG-VMware-Snapshot

#>
param(
    [string]$ViServer = '',
    [string]$User = '',
    [string]$Password = '',
    [string]$ExcludeVMName = '',
    [string]$ExcludeFolder = '',
    [string]$ExcludeRessource = '',
    [string]$ExcludeVMHost = '',
    [string]$ExcludeSnapDescription = '',
    [string]$ExcludeSnapName = '',
    [string]$IncludeVMName = '',
    [string]$IncludeFolder = '',
    [string]$IncludeRessource = '',
    [string]$IncludeVMHost = '',
    [string]$IncludeSnapDescription = '',
    [string]$IncludeSnapName = '',
    [int]$WarningHours = 24,
    [int]$ErrorHours = 48,
    [int]$WarningSize = 10, #in GB
    [int]$ErrorSize = 20     #in GB
)

#Catch all unhandled Errors
trap {
    if ($connected) {
        $null = Disconnect-VIServer -Server $ViServer -Confirm:$false -ErrorAction SilentlyContinue
    }
    $Output = "line:$($_.InvocationInfo.ScriptLineNumber.ToString()) char:$($_.InvocationInfo.OffsetInLine.ToString()) --- message: $($_.Exception.Message.ToString()) --- line: $($_.InvocationInfo.Line.ToString()) "
    $Output = $Output.Replace("<", "")
    $Output = $Output.Replace(">", "")
    $Output = $Output.Replace("#", "")
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
    if ($myInvocation.Line) {
        [string]$output = &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile $myInvocation.Line
    }
    else {
        [string]$output = &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile -file "$($myInvocation.InvocationName)" $args
    }

    #Remove any text after </prtg>
    try {
        $output = $output.Substring(0, $output.LastIndexOf("</prtg>") + 7)
    }

    catch {
    }

    Write-Output $output
    exit
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
}
catch {
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>Error Loading VMware Powershell Module ($($_.Exception.Message))</text>"
    Write-Output "</prtg>"
    Exit
}

# Parameter empty = 999
# if you dont need size or hours just leave it empty
if (($WarningHours -eq "") -and ($WarningHours -ne 0)) {
    $WarningHours = 999
}
if (($ErrorHours -eq "") -and ($ErrorHours -ne 0)) {
    $ErrorHours = 999
}
if (($WarningSize -eq "") -and ($WarningSize -ne 0)) {
    $WarningSize = 999
}
if (($ErrorSize -eq "") -and ($ErrorSize -ne 0)) {
    $ErrorSize = 999
}

# PowerCLI Configuration Settings
try {
    #Ignore certificate warnings
    Set-PowerCLIConfiguration -InvalidCertificateAction ignore -Scope User -Confirm:$false | Out-Null

    #Disable CEIP
    Set-PowerCLIConfiguration -ParticipateInCeip $false -Scope User -Confirm:$false | Out-Null
}

catch {
    Write-Output "Error in Set-PowerCLIConfiguration but we will ignore it." #Error when another Script is currently accessing it.
}

# Connect to vCenter
try {
    $null = Connect-VIServer -Server $ViServer -User $User -Password $Password
            
    $connected = $true
}
 
catch {
    Write-Output "<prtg>"
    Write-Output "<error>1</error>"
    Write-Output "<text>Could not connect to vCenter server $ViServer. Error: $($_.Exception.Message)</text>"
    Write-Output "</prtg>"
    Exit
}

# Get a list of all VMs
try {
    $VMs = Get-VM

}
catch {
    Write-Output "<prtg>"
    Write-Output "<error>1</error>"
    Write-Output "<text>Could not Get-VM. Error: $($_.Exception.Message)</text>"
    Write-Output "</prtg>"
    Exit
}

# Region: VM Filter (Include/Exclude)
# hardcoded list that applies to all hosts
$ExcludeVMNameScript = '^(TestIgnore)$' 
$IncludeVMNameScript = ''

#VM Name
if ($ExcludeVMName -ne "") {
    $VMs = $VMs | Where-Object { $_.Name -notmatch $ExcludeVMName }  
}

if ($ExcludeVMNameScript -ne "") {
    $VMs = $VMs | Where-Object { $_.Name -notmatch $ExcludeVMNameScript }  
}

if ($IncludeVMName -ne "") {
    $VMs = $VMs | Where-Object { $_.Name -match $IncludeVMName }  
}

if ($IncludeVMNameScript -ne "") {
    $VMs = $VMs | Where-Object { $_.Name -match $IncludeVMNameScript }  
}

#VM Folder
if ($ExcludeFolder -ne "") {
    $VMs = $VMs | Where-Object { $_.Folder.Name -notmatch $ExcludeFolder }  
}

if ($IncludeFolder -ne "") {
    $VMs = $VMs | Where-Object { $_.Folder.Name -match $IncludeFolder }  
}

#VM Resource
if ($ExcludeRessource -ne "") {
    $VMs = $VMs | Where-Object { $_.ResourcePool.Name -notmatch $ExcludeRessource }  
}

if ($IncludeRessource -ne "") {
    $VMs = $VMs | Where-Object { $_.ResourcePool.Name -match $IncludeRessource }  
}

#VM Host
if ($ExcludeVMHost -ne "") {
    $VMs = $VMs | Where-Object { $_.VMHost.Name -notmatch $ExcludeVMHost }  
}

if ($IncludeVMHost -ne "") {
    $VMs = $VMs | Where-Object { $_.VMHost.Name -match $IncludeVMHost }  
}
#End Region VM Filter

# Get Snapshots from every VM
$AllSnaps = New-Object -TypeName "System.Collections.ArrayList"
foreach ($VM in $VMs) {
    $Snaps = Get-Snapshot -VM $VM -ErrorAction SilentlyContinue
    foreach ($Snap in $Snaps) {
        # Save VM names for later use
        $null = $AllSnaps.Add($Snap)
    }
}

# Snapshot filter (include/exclude)
# Snapshot Name
if ($ExcludeSnapName -ne "") {
    $AllSnaps = $AllSnaps | Where-Object { $_.Name -notmatch $ExcludeSnapName }  
}

if ($IncludeSnapName -ne "") {
    $AllSnaps = $AllSnaps | Where-Object { $_.Name -match $IncludeSnapName }  
}

# Snapshot Description
if ($ExcludeSnapDescription -ne "") {
    $AllSnaps = $AllSnaps | Where-Object { $_.Description -notmatch $ExcludeSnapDescription }  
}

if ($IncludeSnapDescription -ne "") {
    $AllSnaps = $AllSnaps | Where-Object { $_.Description -match $IncludeSnapDescription }  
}


$WarningCount = 0
$ErrorCount = 0
$AllCount = $AllSnaps.Count
$MaxAge = 0
$MaxSizeMB = 0


foreach ($Snap in $AllSnaps) {
    $date = $snap.created -as [DateTime]
    $dateoutput = (Get-Date -Date $date -Format "dd.MM.yy-HH:mm").ToString()
    $size = [math]::Round(($Snap.SizeGB), 2)
    if ($null -eq $Snap.VM) {
        $name = "None_$($Snap.VMId)"
    }
    else {
        $name = ($Snap.VM).ToString()
    }
    
    #Max Snap Size
    $TempSize = [math]::Round(($Snap.SizeMB * 1048576 ), 0)
    if ($TempSize -gt $MaxSizeMB) {
        $MaxSizeMB = $TempSize   
    }

    #Max Snap Age
    $TempAge = [math]::Round((((Get-Date) - $date).TotalSeconds), 0)
    if ($TempAge -gt $MaxAge) {
        $MaxAge = $TempAge 
    }

    #Check Error Limit
    if (($Snap.SizeGB -ge $ErrorSize) -or ($date -le (Get-Date).AddHours(-$ErrorHours))) {
        $ErrorVMs += "VM=$($name) Created=$($dateoutput) Size=$($size)GB; "
        $ErrorCount += 1
    }

    #Check Warning Limit
    elseif (($Snap.SizeGB -ge $WarningSize) -or ($date -le (Get-Date).AddHours(-$WarningHours))) {
        $WarningVMs += "VM=$($name) Created=$($dateoutput) Size=$($size)GB; " 
        $WarningCount += 1
    }
}


# Disconnect from vCenter
$null = Disconnect-VIServer -Server $ViServer -Confirm:$false

$connected = $false

# Results
$xmlOutput = '<prtg>'
if ($ErrorCount -ge 1) {
    $xmlOutput = $xmlOutput + "<text>Error - $($ErrorVMs)</text>"
}

if (($WarningCount -ge 1) -and ($ErrorCount -eq 0)) {
    $xmlOutput = $xmlOutput + "<text>Warning - $($WarningVMs)</text>"
} 

if (($WarningCount -eq 0) -and ($ErrorCount -eq 0)) {
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
        </result>
        
        <result>
        <channel>oldest Snapshot</channel>
        <value>$([decimal]$MaxAge)</value>
        <unit>TimeSeconds</unit>
        </result>
        
        <result>
        <channel>largest Snapshot</channel>
        <value>$([decimal]$MaxSizeMB)</value>
        <unit>BytesDisk</unit>
        </result>"   
        



$xmlOutput = $xmlOutput + "</prtg>"

Write-Output $xmlOutput
