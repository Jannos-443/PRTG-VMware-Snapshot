# PRTG-VMware-Snapshot
# About

## Project Owner:

Jannos-443

## Project Details

This Sensor Monitors Snapshots with specific Age or Size.

Default Values:
- WarningHours = 24 (hours)
- ErrorHours = 48 (hours)
- WarningSize = 10 (GB)
- ErrorSize = 20 (GB)

## HOW TO

1. Download PSx64.exe from PRTG Tools Familiy https://prtgtoolsfamily.com/downloads/sensors

2. Make sure the VMware PowerCLI Module exists on the Probe under the Powershell Module Path
- C:\Program Files\WindowsPowerShell\Modules\VMware.VimAutomation.Core

3. Place "PSx64.exe" and "PRTG-VMware-Snapshot-Age.ps1" under "C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXE"

4. Create new Sensor PSx64.exe -f="PRTG-VMware-Snapshot.ps1" -p="%VCenter%" "%Username%" "%PW%"
- Set "Scanning Interval" to min "10 minutes"
![PRTG-VMware-Snapshot](media/Sensor-Scan-Intervall.png)


5. Change "Value" Channel >> "Lookups and Limits" to "Enable alerting based on limits"
- Upper Error Limit 1
- Upper Warning Limit 0
![PRTG-VMware-Snapshot](media/Sensor-Limit-Channel.png)
![PRTG-VMware-Snapshot](media/Sensor-Limit.png)



## Examples
![PRTG-VMware-Snapshot](media/Limits-OK.png)
![PRTG-VMware-Snapshot](media/Limits-Warning.png)
![PRTG-VMware-Snapshot](media/Limits-Error.png)
