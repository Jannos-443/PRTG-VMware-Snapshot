<#
    https://github.com/Jannos-443/PRTG-VMware-Snapshot

    Copy this script to the PRTG probe EXE scripts folder (${env:ProgramFiles(x86)}\PRTG Network Monitor\Custom Sensors\EXE)
    and create a "EXE/Script" sensor. Choose this script from the dropdown and set at least:

    + Parameters: VCenter, Username, Password
    + Upper Error Limit 1
    + Upper Warning Limit 0
    + Scanning Interval: minimum 5 minutes

    .PARAMETER ViServer
    The Hostname of the VCenter Server

    .PARAMETER UserName
    Provide the VCenter Username

    .PARAMETER Password
    Provide the VCenter Password

    .PARAMETER IgnorePattern
    Regular expression to describe the VM Name for Example "Test" to exclude every VM with Test in the name

    Example: ^(DemoTestServer|DemoAusname2)$
    
    .PARAMETER WarningHours
    Warninglimit for Snapshot Age
    
    .PARAMETER ErrorHours
    Errorlimit for Snapshot Age

    .PARAMETER WarningSize
    Warninglimit for Snapshot Size

    .PARAMETER ErrorSize
    Errorlimit for Snapshot Size
    
    .EXAMPLE
    Sample call from PRTG EXE/Script
    EXE/Script= PSx64.exe
    Parameters= -f="PRTG-VMware-Snapshot.ps1" -p="%VCenter%" "%Username%" "%PW%"

    Author:  Jannes Brinkmann

#>
param(
    [Parameter(Mandatory)] [string]$ViServer = $null,
    [Parameter(Mandatory)] [string]$User = $null,
    [Parameter(Mandatory)] [string]$Password = $null,
    [string]$IgnorePattern = '(DemoTestServer|DemoAusname2)', #VMs to ignore
    [int]$WarningHours = 24,
    [int]$ErrorHours = 48,
    [int]$WarningSize = 10,  #in GB
    [int]$ErrorSize = 20     #in GB
)

try{
$WarningVMs = ""
$ErrorVMs = ""

# Error if there's anything going on
$ErrorActionPreference = "Stop"


# Import VMware PowerCLI module
$ViModule = "VMware.VimAutomation.Core"

try {
    Import-Module $ViModule -ErrorAction Stop
} catch {
    Write-Host "Error Loading VMware Powershell Module ($($_.Exception.Message))"
    Exit 2
}

# Parameter empty = 999
# if you don´t need Size or Hours just leave it empty
if($WarningHours -eq ""){
    $WarningHours = 999
    }
if($ErrorHours -eq ""){
    $ErrorHours = 999
    }
if($WarningSize -eq ""){
    $WarningSize = 999
    }
if($ErrorSize -eq ""){
    $ErrorSize = 999
    }


# Ignore certificate warnings
Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false | Out-Null


# Connect to vCenter
try {
    Connect-VIServer -Server $ViServer -User $User -Password $Password -ErrorAction Stop | Out-Null
} catch {
    Write-Host "Could not connect to vCenter server $ViServer. Error: $($_.Exception.Message)"
    Exit 2
}

# Get a list of all VMs
try {
    $VMs = Get-VM -ErrorAction Stop

} catch {
    Write-Host "Could in Get-VM. Error: $($_.Exception.Message)"
    Exit 2
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

#Remove Ignored VMs
$AllSnaps = $AllSnaps | where {$_.VM -notmatch $IgnorePattern} 

foreach ($Snap in $AllSnaps){
    if(($Snap.Size -ge $ErrorSize) -or ($Snap.Created -le (get-date).AddHours(-$ErrorHours)))
        {
        $ErrorVMs += "VM=$($Snap.VM) Created=$(($snap.Created).ToString("yy-MM-dd_HH-mm")) Size=$([math]::Round(($Snap.SizeGB),2))GB; "
        }
    if(($Snap.Size -ge $WarningSize) -or ($Snap.Created -le (get-date).AddHours(-$WarningHours)))
        {
        $WarningVMs  += "VM=$($Snap.VM) Created=$(($snap.Created).ToString("yy-MM-dd_HH-mm")) Size=$([math]::Round(($Snap.SizeGB),2))GB; " 
        }
        


}


# Disconnect from vCenter
Disconnect-VIServer -Server $ViServer -Confirm:$false

}

catch{
    Disconnect-VIServer -Server $ViServer -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Script Failed"
    Exit 2
    }



# Results
if ($ErrorVMs -ne "") {
    Write-Host "2:Error - $($ErrorVMs)"
    # Write-Host "Error - $($ErrorVMs)"  #Will Display the Message but "No data" and default says Error after two Times no Data...
    exit 2
    }

if ($WarningVMs -ne ""){
    Write-Host "1:Warning - $($WarningVMs)"
    exit 1
    } 

else {
    Write-Host "0:No Snapshots older $($WarningHours) hours or greater $($WarningSize)GB"
    exit 0
}
