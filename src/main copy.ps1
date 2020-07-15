Import-Module -Name .\lib\SetAzAD.psm1 -Force
Import-Module -Name .\lib\GetVM.psm1 -Force
Import-Module -Name .\lib\GetDisk.psm1 -Force
Import-Module -Name .\lib\ARMTemplate.psm1 -Force
Import-Module -Name .\lib\StorageTable.psm1 -Force
Import-Module -Name .\lib\Snapshots.psm1 -Force

####################################################################################################################################################################
### Config
####################################################################################################################################################################

$config = (Get-Content -Raw -Path ..\config\config.json) | ConvertFrom-Json

####################################################################################################################################################################
####################################################################################################################################################################

$tenant = '<your-tenant>'
$subscription = '<your-subscription>'
$clientCredType = 'client_credentials'
$clientId = '<your-app-id>'
$clientSecret = '<your-app-secret>'
$clientResource = 'https://management.azure.com'


## Load Subscription
$azAdInfo = SetAzAd -tenant $tenant -subscription $subscription
$azAdInfo.setToken($clientCredType, $clientId, $clientSecret, $clientResource);

## Get VM Information Module
$vmInfo = GetVmInformation -azAdInfo $azAdInfo

## Get Disk Imformation Module
$diskInfo = GetDiskInformation -azAdInfo $azAdInfo

## Get ARM Module
$armModule = GetARMTemplate

## Get Storage Table Module
$storageTable = StorageTable -azAdInfo $azAdInfo -storageAccoutResourceGroup $config.storageTable.resourceGroup -storageAccoutName $config.storageTable.storageName

##############################
##### Get Disk Info
$vmInfo.cleanVMInfo()

## Get disk info from VM using Azure REST
##$vmInfo.getVirtualMachine('RG-SnapshotBackup', 'VM-SnapshotBackup')

## for CSV
$getDisks = Import-Csv -Path ..\vmdisk.csv

## for Others
# You should make the object like :
<#
[
    {
        "diskId": "your-OS-Disk-Id",
        "lun": "empty-here-for-os"
    },
    {
        "diskId": "your-Data-Disk-Id",
        "lun": "data-disk-lun"
    }
]
# It is okay to empty value for lun
#>

##### Get Disk Info
##############################

$diskInfo.cleanDiskList()
foreach($diskId in $getDisks) {
    $diskInfo.getManagedDiskbyIDwithGetVM($diskId.diskId, $diskId.lun)
}

[PSCustomObject[]]$diskResult = $null
$diskFromDiskInfo = $null
foreach($diskFromDiskInfo in $diskInfo.disks) {
    $armModule.setResourceType('disk')
    $date = Get-Date -Format $config.snapshotName.postfix
    $armModule.setArmDisk(($config.snapshotName.prefix + $diskFromDiskInfo.diskName), $date, $diskFromDiskInfo.diskId, $diskFromDiskInfo.diskSize, $diskFromDiskInfo.sku_name, $diskFromDiskInfo.sku_tier, $diskFromDiskInfo.osType)
    
    ## Load Snapshot Class
    $diskName = ($armModule.getRequestBody() | ConvertFrom-Json).properties.parameters.snapshots_Name.value
    $storageSnapshot = LoadDiskSnapshots -azAdInfo $azAdInfo `
                                         -diskFromDiskInfo $diskFromDiskInfo `
                                         -config $config
    # Creating Snapshot
    $diskResultInPromise = $storageSnapshot.createDiskSnapshotWithARM($diskFromDiskInfo.diskResourceGroup, $armModule.getRequestBody(), $diskName)
    # If Snapshot Created and HTTP Status Codes are 20x
    if($diskResultInPromise -and $diskResultInPromise.StatusCode -ge 200) {
        do {
            # If Snapshot Created and HTTP Status Code is 200
            $header = @{
                "Authorization"="bearer " + $azAdInfo.token.access_token
            }
            $promise = Invoke-WebRequest -Method Get `
                        -Headers $header `
                        -Uri ($diskResultInPromise.Headers.'Azure-AsyncOperation'[0])
        } while ($promise.StatusCode -ne 200)
        $diskFromDiskInfo | Add-Member -NotePropertyName "PartitionKey" -NotePropertyValue "beforeGeneratedAccessURL"
        $diskFromDiskInfo | Add-Member -NotePropertyName "RowKey" -NotePropertyValue $diskName
        $diskResult += $diskFromDiskInfo
    }
}

foreach ($item in $diskResult) {
    $storageTable.insertData('test', ($item | ConvertTo-Json))    
}


$queryData = $storageTable.selectByQuery('test', "vmName eq 'VM-SnapshotBackup'") | ConvertFrom-Json
$queryData.value[0].diskResourceGroup
$queryData.value[0].RowKey

$queryData.value[0].PSobject.Properties.Remove('odata.etag')
$queryData.value[0].PartitionKey = "AfterGeneratedAccessURL"
$queryData.value[0] | Add-Member -NotePropertyName "AccessURL" -NotePropertyValue ""

$body = '{
    "access": "Read",
    "durationInSeconds": 3600
}'
$header.Add("Content-Type", "application/json")
$requestGrantAccess = Invoke-WebRequest -Method Post `
                                        -Uri ("https://management.azure.com/subscriptions/" + 
                                              $azAdInfo.subscription + 
                                              "/resourceGroups/" + 
                                              $queryData.value[0].diskResourceGroup + 
                                              "/providers/Microsoft.Compute/snapshots/" + 
                                              $queryData.value[0].RowKey + 
                                              "/beginGetAccess?api-version=2019-07-01") `
                                        -Headers $header `
                                        -Body ([System.Text.Encoding]::UTF8.GetBytes($body))

$requestGrantAccess.Headers.Location
$requestGrantAccess.Headers.'Azure-AsyncOperation'[0]
$qqq = Invoke-WebRequest -Method Get -Uri $requestGrantAccess.Headers.Location[0] -Headers $header
$qqq2 = Invoke-WebRequest -Method Get -Uri $requestGrantAccess.Headers.'Azure-AsyncOperation'[0] -Headers $header
# $storageTable.deleteDataByQuery('test', "vmName eq 'VM-SnapshotBackup'")