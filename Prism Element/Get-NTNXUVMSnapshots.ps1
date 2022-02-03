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
 .PARAMETER Age
  Display only Age without creating date of the snapshot
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
    $ExportCSVPAth,
    #$ExportCSVPath = "C:\tools\SnapshotExport.csv" | If you want to set a default CSV location you can do this here.

    [Parameter(Mandatory=$false)]
    [switch]
    $Age
)

#Variables

$NTNXCluster = $NTNXCluster.Split(";")
$NTNXException = $NTNXException.Split(";")

$NTNXCredentials = Get-Credential -Message "Please provide Nutanix administrator credentials (e.g.: admin@domain.suffix):"

## Varianbles for age parameter
#If you want to set other threshold for coloring the console output you can do so here.

$ageRed = 30
$ageYellow = 7

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
    $Column4 = New-Object System.Data.DataColumn Age,([int32])
    $Results.Columns.Add($Column1)
    $Results.Columns.Add($Column2)
    $Results.Columns.Add($Column3)
    $Results.Columns.Add($Column4)

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
        $SnapshotAge = ((Get-Date) - $SnapshotCreationTime).Days

        $Row = $Results.NewRow()
        $Row."VM-Name" = $VMname
        $Row."Snapshot-Name" = $SnapshotName
        $Row."Creation-Time" = $SnapshotCreationTime
        $Row."Age" = $SnapshotAge
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
    $Results | Format-Table VM-Name, Snapshot-Name, Creation-Time, @{
        Label      = "Age"
        Expression =
        ##Using escape codes
        #Color table
        #Red:       31
        #Green:     32
        #Yellow:    33
        #Blue:      34
        #Magenta:   35
        #Cyan:      36
        {
            if ($_.Age -ge $ageRed) {

                $color = "31" #red
            }
            elseif ($_.Age -ge $ageYellow) {

                $color = "33" #yellow
            }
            else {

                $color = "0" #white
            }
            $e = [char]27
            "$e[${color}m$($_.Age)${e}[0m"
        }
    }
}

#endregion
