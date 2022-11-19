# Get-NTNXUVMSnapshots.ps1

Query snapshots from Nutanix Prism

## Examples

### Get all Snapshots of the Cluster NTNXCL01.internal.network
.\Get-NTNXUVMSnapshots.ps1 -NTNXCluster "NTNXCL01.internal.network"

### Get all Snapshots of the Cluster NTNXCL01.internal.network and export the output to CSV
.\Get-NTNXUVMSnapshots.ps1 -NTNXCluster "NTNXCL01.internal.network" -ExportCSV $true -ExportCSVPAth "C:\tools\SnapshotExport.csv"

## Tested Environments

AOS: 6.5.1
Powershell 5.1 on Windows Server 2019

AOS 5.20.x should still work

## Known Errors

### Connect-NTNXCluster command was failing with error: "The request was aborted: Could not create SSL/TLS secure channel"

Nutanix Cluster was using RSA based certificate and the Windows 2019 Client was not sending any of the ciphers accepted by Prism.
Since AOS 5.20.4, several of the weak ciphers have been removed from the Nutanix Cluster: https://portal.nutanix.com/kb/12970

Once the Windows Client was configured to also send the below ciphers, Connect-NTNXCluster commands were successful:
```
TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
