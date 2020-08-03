[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [String]$tenant,
    [Parameter(Mandatory=$true)]
    [String]$subscription,
    [Parameter(Mandatory=$true)]
    [String]$clientId,
    [Parameter(Mandatory=$true)]
    [String]$clientSecret,
    [Parameter(Mandatory=$true)]
    [String]$storageAccountResourceGroup,
    [Parameter(Mandatory=$true)]
    [String]$storageAccountName,
    [Parameter(Mandatory=$true)]
    [String]$sourceDiskId
)

$config = '{
    "snapshotName": {
        "prefix": "BS-",
        "postfix": "yy-MM-ddTHH-mm"
    },
    "storageTable": {
        "resourceGroup": "RG-SnapshotBackup",
        "storageName": "pcwstoragetable"
    }
}' | ConvertFrom-Json

$clientCredType = 'client_credentials'
$clientResource = 'https://management.azure.com'


## Set Azure AD Token
$AzAdInfo = SetAzAd -tenant $tenant -subscription $subscription
$AzAdInfo.setToken($clientCredType, $clientId, $clientSecret, $clientResource);


## Disk Information Module
$DiskInfo = GetDiskInformation -azAdInfo $AzAdInfo


## Get ARM Module
$ArmModule = GetARMTemplate


## Get Storage Modules
# Table
$StorageTable = StorageTableFromAD -azAdInfo $AzAdInfo `
                                   -storageAccoutResourceGroup $storageAccountResourceGroup `
                                   -storageAccoutName $storageAccountName

# Blob
$StorageBlob = StorageBlobFromAD -azAdInfo $AzAdInfo `
                                 -storageAccoutResourceGroup $storageAccountResourceGroup `
                                 -storageAccoutName $storageAccountName


############################################################################################################################################
############################################################################################################################################
##
## Starting Script
##
############################################################################################################################################
############################################################################################################################################
try {
    $null = $DiskInfo.getManagedDiskbyID($sourceDiskId, "")
    Write-Output $DiskInfo.disks[0].vmName + $DiskInfo.disks[0].diskName
    $diskFromRest = $DiskInfo.disks
} catch {
    Write-Output Error
    Write-Output $_
    return
}


## Prepare for Template
if ($ArmModule.setResourceType('disk')) {
    $postfix = Get-Date -Format $config.snapshotName.postfix
    $diskName = "{0}{1}" -f $config.snapshotName.prefix, $diskFromRest.diskName
    $diskId = $diskFromRest.diskId
    $diskSize = $diskFromRest.diskSize
    $diskSkuName = $diskFromRest.sku_name
    $diskSkuTier = $diskFromRest.sku_tier
    $diskOsType = $diskFromRest.osType

    $armModule.setArmDisk($diskName, $postfix, $diskId, $diskSize, $diskSkuName, $diskSkuTier, $diskOsType)

    $snapshotName = ($ArmModule.getRequestBody() | ConvertFrom-Json).
                                properties.parameters.snapshots_Name.value
} else {
    return
}


## Creating Snapshot with ARM Template
$resourceGroup = $diskFromRest.diskResourceGroup
$reqBody = $ArmModule.getRequestBody()
$DiskSnapshot = LoadDiskSnapshots -azAdInfo $AzAdInfo
$snapshotPromise = $DiskSnapshot.createDiskSnapshotWithARM($resourceGroup, $reqBody, $diskName)
$promiseUrl = $snapshotPromise.Headers.'Azure-AsyncOperation'

$snapshotPromise.Headers.'Azure-AsyncOperation'
$promiseUrl


## Monitoring Promise & Validation // Creating DiskSnapshot
do {
    $header = @{
        "Authorization"="bearer " + $azAdInfo.token.access_token
    }
    $promise = Invoke-WebRequest -Method Get `
                                 -Headers $header `
                                 -Uri ($promiseUrl) `
                                 -UseBasicParsing
    Write-Output ($promise.Content | ConvertFrom-Json).status
    Start-Sleep -Seconds 1
} until (($promise.Content | ConvertFrom-Json).status -eq "Succeeded")


## Monitoring Promise & Validation // Grant SAS to Snapshot
$snapshotObject = $DiskSnapshot.getSnapshot($resourceGroup, $snapshotName)
if($snapshotObject.StatusCode -eq 200) {
    $grantSasPromise = $DiskSnapshot.grantAccessURL(3600, $resourceGroup, $snapshotName)
    $sasPromiseUrl = $grantSasPromise.Headers.'Azure-AsyncOperation'
    $sasPromise = $null
    do {
        $header = @{
            "Authorization"="bearer " + $azAdInfo.token.access_token
        }
        $sasPromise = Invoke-WebRequest -Method Get `
                                     -Headers $header `
                                     -Uri ($sasPromiseUrl) `
                                     -UseBasicParsing
        $sasPromiseContent = $sasPromise.Content | ConvertFrom-Json
        Write-Output $sasPromiseContent.status
        $snapShotSasUrl = $sasPromiseContent.properties.output.accessSAS
        Start-Sleep -Seconds 1
    } until (($sasPromise.Content | ConvertFrom-Json).status -eq "Succeeded")

}



$snapshotVhd = $snapshotName + ".vhd"
$startBlobCopy = $StorageBlob.startStoragePageBlobCopyFromURL($snapShotSasUrl, "blob", $snapshotVhd)
if($startBlobCopy.StatusCode -ge 200) {
    [PSCustomObject]$body = [PSCustomObject]::new()
    $originBlobCopyId = $startBlobCopy.Headers.'x-ms-copy-id'
    $body | Add-Member -NotePropertyName "PartitionKey" -NotePropertyValue $startBlobCopy.Headers.'x-ms-copy-id'
    $body | Add-Member -NotePropertyName "copyId" -NotePropertyValue $startBlobCopy.Headers.'x-ms-copy-id'
    $body | Add-Member -NotePropertyName "RowKey" -NotePropertyValue $snapshotVhd
    $body | Add-Member -NotePropertyName "xmsCopyStatus" -NotePropertyValue $startBlobCopy.Headers.'x-ms-copy-status'
    $body | Add-Member -NotePropertyName "Timestamp" -NotePropertyValue $startBlobCopy.Headers.Date
    $body | Add-Member -NotePropertyName "snapshotName" -NotePropertyValue $snapshotName
    $body | Add-Member -NotePropertyName "storedStorage" -NotePropertyValue $StorageBlob.storageAccount
    $body | Add-Member -NotePropertyName "blobContainer" -NotePropertyValue "blob"
    $body | Add-Member -NotePropertyName "vhdName" -NotePropertyValue $snapshotVhd
    $StorageTable.insertData("azureblobcopyurl", ($body | ConvertTo-Json))

    $query = "RowKey eq '{0}'" -f $snapshotVhd
    $blobCopyInfo = $storageTable.selectByQuery('azureblobcopyurl', $query) | ConvertFrom-Json

    $blobCopyStatus = $StorageBlob.getBlobCopyStatus($blobCopyInfo.value[0].blobContainer, $blobCopyInfo.value[0].vhdName)
    if($blobCopyStatus.StatusCode -ge 200) {
    
        $destBlobCopyId = $blobCopyStatus.Headers.'x-ms-copy-id'

        if($originBlobCopyId -eq $destBlobCopyId) {
            
            do {
                $blobCopyStatus = $StorageBlob.getBlobCopyStatus($blobCopyInfo.value[0].blobContainer, $blobCopyInfo.value[0].vhdName)
                $percent = $blobCopyStatus.Headers.'x-ms-copy-progress'.Split("/")
                $output = "{0} | {1} : {2} | {3:P2}" -f (Get-Date), $blobCopyStatus.Headers.'x-ms-copy-status', $blobCopyStatus.Headers.'x-ms-copy-progress', ($percent[0] / $percent[1])
                Write-Output $output
                Start-Sleep -Seconds 5
            } until ($blobCopyStatus.Headers.'x-ms-copy-status' -eq "success")
            $blobCopyStatus.Headers.'x-ms-copy-id'

            [PSCustomObject]$body = [PSCustomObject]::new()
            $body | Add-Member -NotePropertyName "PartitionKey" -NotePropertyValue $blobCopyStatus.Headers.'x-ms-copy-id'
            $body | Add-Member -NotePropertyName "copyId" -NotePropertyValue $blobCopyStatus.Headers.'x-ms-copy-id'
            $body | Add-Member -NotePropertyName "RowKey" -NotePropertyValue $blobCopyInfo.value[0].snapshotName
            $body | Add-Member -NotePropertyName "xmsCopyStatus" -NotePropertyValue $blobCopyStatus.Headers.'x-ms-copy-status'
            $body | Add-Member -NotePropertyName "Timestamp" -NotePropertyValue $blobCopyStatus.Headers.'x-ms-copy-completion-time'
            $body | Add-Member -NotePropertyName "snapshotName" -NotePropertyValue $blobCopyInfo.value[0].snapshotName
            $body | Add-Member -NotePropertyName "storedStorage" -NotePropertyValue $blobCopyInfo.value[0].storedStorage
            $body | Add-Member -NotePropertyName "blobContainer" -NotePropertyValue $blobCopyInfo.value[0].blobContainer
            $body | Add-Member -NotePropertyName "vhdName" -NotePropertyValue $blobCopyInfo.value[0].vhdName
            $body | Add-Member -NotePropertyName "ContentLength" -NotePropertyValue $blobCopyStatus.Headers.'Content-Length'
            $StorageTable.insertData("completedcopyjob", ($body | ConvertTo-Json))
            $storageTable.deleteDataByQuery('azureblobcopyurl', $query)

        }

    }

}

$requestRevokeAccess = $DiskSnapshot.revokeAccessURL($resourceGroup, $snapshotName)
do {
    $header = @{
        "Authorization"="bearer " + $azAdInfo.token.access_token
    }
    $promise = Invoke-WebRequest -Method Get `
                                 -Headers $header `
                                 -Uri $requestRevokeAccess.Headers.'Azure-AsyncOperation' `
                                 -UseBasicParsing
    Write-Host ($promise.Content | ConvertFrom-Json).status
    Start-Sleep -Seconds 1
} until (($promise.Content | ConvertFrom-Json).status -eq "Succeeded")