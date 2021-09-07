# Get-NTNXUVMSnapshots.ps1

## Examples

### Get all Snapshots of the Cluster NTNXCL01.internal.network
.\Get-NTNXUVMSnapshots.ps1 -NTNXCluster "NTNXCL01.internal.network"

### Get all Snapshots of the Cluster NTNXCL01.internal.network and export the output to CSV
.\Get-NTNXUVMSnapshots.ps1 -NTNXCluster "NTNXCL01.internal.network" -ExportCSV $true -ExportCSVPAth "C:\tools\SnapshotExport.csv"

## Tested Environments

AOS: 5.20.1.1
Powershell 5.1 on Windows Server 2019
