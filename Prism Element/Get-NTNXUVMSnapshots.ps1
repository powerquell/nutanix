<#
 .Description
  Display Snapshots of Nutanix UVMs

  !!!DISCLAIMER!!!
  This code is made available "as-is" without warranty of any kind.
  The entire risk of the use or the results from the use of this code remains with the user.

 .PARAMETER NTNXCluster
  FQDN of Cluster(s). To define multiple Clusters use ";" to split entries.
 .PARAMETER NTNXException
  Exclude Snapshots with filter. Like "SnapB*"
 .PARAMETER ExportCSV
  Switch for CSV Export
 .PARAMETER ExportCSVPAth
  Destiantion for the CSV File
 .Notes
    Author: Erik Hirschfelder - https://github.com/powerquell
    Last edit: 2021-09-07
    Forked from : https://chrisjeucken.com/2018/07/query-all-snapshots-from-nutanix-ahv/
 .Example
    .\Get-NTNXUVMSnapshots.ps1 -NTNXCluster "NTNXCL01.internal.network"
    Get all Snapshots of the Cluster NTNXCL01.internal.network

    .\Get-NTNXUVMSnapshots.ps1 -NTNXCluster "NTNXCL01.internal.network" -ExportCSV $true -ExportCSVPAth "C:\tools\SnapshotExport.csv"
    Get all Snapshots of the Cluster NTNXCL01.internal.network and export the Output to C:\tools\SnapshotExport.csv
#>
#region variables and parameter

param (
    [Parameter(Mandatory=$true)]
    [String]
    $NTNXCluster,
    #$NTNXCluster = "fqdn.of.ntnx.cluster" | If you want to set a default Cluster you can do this here.

    [Parameter(Mandatory=$false)]
    [String]
    $NTNXException,
    #$NTNXException = "exeption" | If you want to set a default Exception you can do this here.

    [Parameter(Mandatory=$false)]
    [Bool]
    $ExportCSV,

    [Parameter(Mandatory=$false)]
    [String]
    $ExportCSVPAth
    #$ExportCSVPath = "C:\tools\SnapshotExport.csv" | If you want to set a default CSV location you can do this here.
)

#Variables

$NTNXCluster = $NTNXCluster.Split(";")
$NTNXException = $NTNXException.Split(";")

$NTNXCredentials = Get-Credential -Message "Please provide Nutanix administrator credentials (e.g.: admin@domain.suffix):"

#endregion
#region import Snapin

try {
    & "C:\Program Files (x86)\Nutanix Inc\NutanixCmdlets\powershell\import_modules\ImportModules.PS1"
    Add-PSSnapin Nutanix*
}
catch {
    throw "Unable to import Snapin. Check NutanixCmdlets Path!"
}

#endregion
#region script

# Connect to Nutanix Clusters
    foreach ($Cluster in $NTNXCluster) {
        try {
            Connect-NTNXCluster -Server $Cluster -Password $NTNXCredentials.Password -UserName $NTNXCredentials.UserName -ErrorAction SilentlyContinue | Out-Null
        } catch {
            Write-Host *** Not able to connect to Nutanix Cluster $Cluster *** -ForegroundColor Red
        }
    }

# Test connection to Nutanix cluster
    if (!(Get-NTNXCluster -ErrorAction SilentlyContinue)) {
        Write-Host *** No functional Nutanix connection available *** -ForegroundColor Red
        exit
    }

# Create results table
    if ($Results) {
        Remove-Variable -Name Results
    }
    $Results = New-Object system.Data.DataTable "All NTNX snapshots"
    $Column1 = New-Object System.Data.DataColumn VM-Name,([string])
    $Column2 = New-Object System.Data.DataColumn Snapshot-Name,([string])
    $Column3 = New-Object System.Data.DataColumn Creation-Time,([string])
    $Results.Columns.Add($Column1)
    $Results.Columns.Add($Column2)
    $Results.Columns.Add($Column3)

# Get all VMs and snapshots
    $AllNTNXVM = Get-NTNXVM -ErrorAction SilentlyContinue
    $AllNTNXSnapshots = Get-NTNXSnapshot -ErrorAction SilentlyContinue

# Handle exceptions (if any)
    if ($NTNXException) {
        foreach ($Exception in $NTNXException) {
            $AllNTNXSnapshots = $AllNTNXSnapshots | Where-Object {$_.snapshotName -notlike $Exception}
        }
    }

# Find VM for each snapshot and export to table
    foreach ($Snapshot in $AllNTNXSnapshots) {
        $VMUuid = $Snapshot.vmUuid
        $VMname = ($AllNTNXVM |  Where-Object {$_.Uuid -eq $VMUuid}).vmName
        $SnapshotName = $Snapshot.snapshotName
        $CreationTimeStamp = ($Snapshot.createdTime)/1000
        $CreationTime = (Get-Date '1/1/1970').AddMilliseconds($CreationTimeStamp)
        $SnapshotCreationTime = $CreationTime.ToLocalTime()

        $Row = $Results.NewRow()
        $Row."VM-Name" = $VMname
        $Row."Snapshot-Name" = $SnapshotName
        $Row."Creation-Time" = $SnapshotCreationTime
        $Results.Rows.Add($Row)
    }

# Disconnect from Nutanix Clusters
    foreach ($Cluster in $NTNXCluster) {
        if (Get-NTNXCluster -ErrorAction SilentlyContinue) {
            Disconnect-NTNXCluster -Server $Cluster
        }
    }

#endregion
#region Output

#Send Output to CSV or Console

if ($ExportCSV) {

    if ($ExportCSVPAth) {
        $Results | Export-Csv -Path $ExportCSVPAth -Delimiter ";" -Encoding UTF8 -NoTypeInformation
    }
    else {
        throw "No Path for CSV defined"
    }
}
else {
    $Results | Format-Table
}

#endregion
