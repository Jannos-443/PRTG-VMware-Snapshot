# PRTG-VMware-Snapshot
# About

## Project Owner:

Jannos-443

## Project Details

This sensor Monitors Snapshots with specific Age or Size.

| Parameter | Default Value |
| --- | --- |
| WarningHours | 24 (hours) |
| ErrorHours | 48 (hours) |
| WarningSize | 10 (GB) |
| ErrorSize | 20 (GB) |

You can exclude/include the following properties:
 - VMName
 - VMFolder
 - VMRessource
 - VMHost
 - SnapshotName
 - SnapshotDescription

## HOW TO

1. Make sure the VMware PowerCLI Module exists on the Probe under the Powershell Module Path
   - `C:\Program Files\WindowsPowerShell\Modules\VMware.VimAutomation.Core`


2. Place `PRTG-VMware-Snapshot.ps1` under `C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML`

3. Create new sensor

   | Settings | Value |
   | --- | --- |
   | EXE/Script Advanced | PRTG-VMware-Snapshot.ps1 |
   | Parameters | -ViServer 'yourVCenterFQDN' -User 'yourUser' -Password 'yourPassword' |
   | Scanning Interval | 10 minutes |


4. Set the "$IgnorePattern" or "$IgnoreScript" parameter to exclude VMs



## Examples

Exclude all VMs with Names that start with "TestVM":

`-ViServer 'yourVCenterFQDN' -User 'yourUser' -Password 'yourPassword' -ExcludeVMName '^(TestVM.*)$'`

Exclude all VMs on the VMHost "ESXI-Test":

`-ViServer 'yourVCenterFQDN' -User 'yourUser' -Password 'yourPassword' -ExcludeVMHost '^(ESXI-Test.contoso.com)$'`

Excude all VMs in the folder "Test":

`-ViServer 'yourVCenterFQDN' -User 'yourUser' -Password 'yourPassword' -ExcludeFolder '^(Test)$'`

Excude all VMs in the folders "Test" AND "unimportant":

`-ViServer 'yourVCenterFQDN' -User 'yourUser' -Password 'yourPassword' -ExcludeFolder '^(Test|unimportant)$'`

ONLY monitor VMs in the folder "Test2":

`-ViServer 'yourVCenterFQDN' -User 'yourUser' -Password 'yourPassword' -IncludeFolder '^(Test2)$'`

![PRTG-VMware-Snapshot](media/ok.png)

![PRTG-VMware-Snapshot](media/error.png)

## Includes/Excludes

You can use the variables to exclude/include VM(s)/Snapshots(s) 
The variables take a regular expression as input to provide maximum flexibility.

For more information about regular expressions in PowerShell, visit [Microsoft Docs](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions).

".+" is one or more charakters
".*" is zero or more charakters
