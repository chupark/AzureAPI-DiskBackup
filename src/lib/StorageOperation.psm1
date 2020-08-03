################################################################################################################################################
#
# Storage Blob
#
################################################################################################################################################

Class StorageBlob {
    [String]$storageAccount
    [String]$date
    hidden [String]$sasHrKey

    $tableOperations = [StorageBlobOperation].GetEnumNames()

    StorageBlob([String]$storageAccount, [String]$key) {
        $this.storageAccount = $storageAccount
        $this.sasHrKey = $key
    }

    [PSCustomObject]startStoragePageBlobCopyFromURL([String]$srcUrl, [String]$destContainer, [String]$destBlobName) {
        $copyDate = [System.DateTime]::UtcNow.ToString("R")
        $canonicalizedHeaders = "x-ms-copy-source:" + $srcUrl       + "`n" + 
                                "x-ms-date:" + $copyDate            + "`n" +
                                "x-ms-version:2018-11-09"           + "`n"
                                 
        $StringToSign = "PUT`n`n`n`n" + $CanonicalizedHeaders +"/"+$this.storageAccount+"/"+$destContainer+"/"+$destBlobName
        
        $sharedKey = [System.Convert]::FromBase64String($this.sasHrKey)
        $hasher = New-Object System.Security.Cryptography.HMACSHA256
        $hasher.Key = $sharedKey
        $signedSignature = [System.Convert]::ToBase64String($hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToSign)))
        
        
        $copyHeader = @{
            "x-ms-copy-source"=$srcUrl
            "x-ms-date"=$copyDate
            "x-ms-version"="2018-11-09"
            "Authorization"="SharedKeyLite " + $this.storageAccount + ":" + $signedSignature
        }
        $uri = "https://{0}.blob.core.windows.net/{1}/{2}" -f $this.storageAccount, $destContainer, $destBlobName
        $invokeResult = Invoke-WebRequest -Method Put -Uri $uri  -Headers $copyHeader -UseBasicParsing
    
        return $invokeResult
    }

    [PSCustomObject]getBlobCopyStatus([String]$destContainer, [String]$destBlobName) {
        $copyDate = [System.DateTime]::UtcNow.ToString("R")
        $canonicalizedHeaders = "x-ms-date:" + $copyDate  +   "`n" +
                                "x-ms-version:2018-11-09" +   "`n"
        $StringToSign = "HEAD`n`n`n`n" + $CanonicalizedHeaders +"/" + $this.storageAccount + "/" + $destContainer + "/" + $destBlobName
        $sharedKey = [System.Convert]::FromBase64String($this.sasHrKey)
        $hasher = New-Object System.Security.Cryptography.HMACSHA256
        $hasher.Key = $sharedKey
        $signedSignature = [System.Convert]::ToBase64String($hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToSign)))

        $getHeader = @{
            "x-ms-date"=$copyDate
            "x-ms-version"="2018-11-09"
            "Authorization"="SharedKeyLite " + $this.storageAccount + ":" + $signedSignature
        }
        $uri = "https://{0}.blob.core.windows.net/{1}/{2}" -f $this.storageAccount, $destContainer, $destBlobName
        
        $blobStatus = Invoke-WebRequest -Method Head -Uri $uri -Headers $getHeader -UseBasicParsing

        return $blobStatus
    }

}

enum StorageBlobOperation {
    startStoragePageBlobCopyFromURL
}


function StorageBlobFromAD() {
    param(
        [PSCustomObject]$azAdInfo,
        [string]$storageAccoutResourceGroup,
        [string]$storageAccoutName
    )
    $saURL = "https://management.azure.com/subscriptions/" + 
              $azAdInfo.subscription + "/resourceGroups/" + 
              $storageAccoutResourceGroup + 
              "/providers/Microsoft.Storage/storageAccounts/" + 
              $storageAccoutName + 
              "/listKeys?api-version=2019-06-01"
    $saHeader = @{
        "Authorization"="Bearer " + $azAdInfo.token.access_token
    }              
    $saData = (Invoke-WebRequest -Method Post `
                                -Uri $saURL `
                                -Headers $saHeader -UseBasicParsing).Content | ConvertFrom-Json

    return [StorageBlob]::new($storageAccoutName, $saData.keys[0].value)
}

function StorageBlob() {
    param(
        [String]$storageAccount,
        [String]$key
    )
    
    return [StorageBlob]::new($storageAccount, $key)
}




################################################################################################################################################
#
# Storage Table
#
################################################################################################################################################

Class StorageTable {
    [String]$storageAccount
    [String]$date
    hidden [String]$sasHrKey

    $tableOperations = [TableOperation].GetEnumNames()

    StorageTable([String]$storageAccount, [String]$key) {
        $this.storageAccount = $storageAccount
        $this.sasHrKey = $key
    }

    [PSCustomObject]setAuthHeader([String]$operation, [String]$tableName, [String]$query) {
        $this.date = [System.DateTime]::UtcNow.ToString("R")
        [PSCustomObject]$header = $null
        $StringToSign = '';
        if($this.tableOperations.Contains($operation)) {
            switch ($operation) {
                'createTable' { 
                    $StringToSign = $this.date + "`n" +  
                                    '/' + $this.storageAccount + '/Tables'
                    break;
                }
                'deleteTable' {
                    break;
                }
                'insertData' {
                    $StringToSign = $this.date + "`n" +  
                                    '/' +$this.storageAccount + '/' + $tableName
                    $header = @{
                        "Authorization" = "SharedKeyLite " + $this.storageAccount + ":" + $this.makeSignedSignature($StringToSign)
                        "Content-Type" = "application/json"
                        "x-ms-date" = $this.date
                        "x-ms-version" = "2013-08-15"
                    }
                    break;
                }
                'updateDataByPartitionKeyAndRowKey' {
                    $StringToSign = $this.date + "`n" +  
                                    '/' +$this.storageAccount + '/' + $tableName + $query
                    $header = @{
                        "Authorization" = "SharedKeyLite " + $this.storageAccount + ":" + $this.makeSignedSignature($StringToSign)
                        "If-Match"="*"
                        "x-ms-date" = $this.date
                    }
                    break;
                }
                'deleteDataByPartitionKeyAndRowKey' {
                    $StringToSign = $this.date + "`n" +  
                                    '/' +$this.storageAccount + '/' + $tableName + $query
                    $header = @{
                        "Authorization" = "SharedKeyLite " + $this.storageAccount + ":" + $this.makeSignedSignature($StringToSign)
                        "If-Match"="*"
                        "x-ms-date" = $this.date
                    }
                    break;
                }
                'deleteDataByTable' {
                    $StringToSign = $this.date + "`n" +  
                                    '/' +$this.storageAccount + '/' + $tableName + "()"
                    break;
                }
                'deleteDataByQuery' {
                    $StringToSign = $this.date + "`n" +  
                                    '/' +$this.storageAccount + '/' + $tableName + "()"
                    $header = @{
                        "Authorization" = "SharedKeyLite " + $this.storageAccount + ":" + $this.makeSignedSignature($StringToSign)
                        "If-Match"="*"
                        "x-ms-date" = $this.date
                    }
                    break;
                }
                'selectByQuery' {
                    $StringToSign = $this.date + "`n" +  
                                    '/' +$this.storageAccount + '/' + $tableName + "()"
                    $header = @{
                        "Authorization" = "SharedKeyLite " + $this.storageAccount + ":" + $this.makeSignedSignature($StringToSign)
                        "x-ms-date" = $this.date
                        "x-ms-version" = "2013-08-15"
                        "Accept" = "application/json;odata=minimalmetadata"
                    }
                    break;
                }
                'selectByTable' {
                    $StringToSign = $this.date + "`n" +  
                                    '/' +$this.storageAccount + '/' + $tableName + "()"
                    $header = @{
                        "Authorization" = "SharedKeyLite " + $this.storageAccount + ":" + $this.makeSignedSignature($StringToSign)
                        "x-ms-date" = $this.date
                        "x-ms-version" = "2013-08-15"
                        "Accept" = "application/json;odata=minimalmetadata"
                    }
                    break;
                }
                Default {
                    return $false
                    break;
                }
            }
        } else {
            return $false
        }
        
        return $header
    }

    hidden [String]makeSignedSignature([String]$StringToSign) {
        $sharedKey = [System.Convert]::FromBase64String($this.sasHrKey)
        $hasher = New-Object System.Security.Cryptography.HMACSHA256
        $hasher.Key = $sharedKey
        $signedSignature = [System.Convert]::ToBase64String($hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToSign)))

        return $signedSignature
    }

    hidden [PSCustomObject]updateDataByPartitionKeyAndRowKey([String]$tableName, [String]$PartitionKey, [String]$RowKey, [String]$jsonBody) {
        $header = $this.setAuthHeader('updateDataByPartitionKeyAndRowKey', $tableName, ("(PartitionKey='" + $PartitionKey + "',RowKey='" + $RowKey + "')"))
        if($header) {
            return Invoke-WebRequest -Uri ("https://"+ $this.storageAccount +".table.core.windows.net/" + $tableName + "(PartitionKey='" + $PartitionKey + "',RowKey='" + $RowKey + "')") `
            -Headers $header `
            -Method Put `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonBody)) `
            -UseBasicParsing
        } return {
            $false
        }
    }

    hidden [PSCustomObject]deleteDataByPartitionKeyAndRowKey([String]$tableName, [String]$PartitionKey, [String]$RowKey) {
        $header = $this.setAuthHeader('deleteDataByPartitionKeyAndRowKey', $tableName, ("(PartitionKey='" + $PartitionKey + "',RowKey='" + $RowKey + "')"))
        if($header) {
            return Invoke-WebRequest -Uri ("https://"+ $this.storageAccount +".table.core.windows.net/" + $tableName + "(PartitionKey='" + $PartitionKey + "',RowKey='" + $RowKey + "')") `
                                 -Headers $header `
                                 -Method Delete `
                                 -UseBasicParsing
        } else {
            return $false
        }
    }

    # Select & Update
    [PSCustomObject]updateDataByQuery([String]$tableName, [String]$query, [String]$jsonData) {
        try{
            $datas = $this.selectByQuery($tableName, $query) | ConvertFrom-Json
            foreach ($data in $datas.value) {
                $this.updateDataByPartitionKeyAndRowKey($tableName, $data.PartitionKey, $data.RowKey, $jsonData)
            }
            return ,$true
        } catch {
            return $_
        }       
    }

    # Select & Remove
    [PSCustomObject]deleteDataByQuery([String]$tableName, [String]$query) {
        try{
            $datas = $this.selectByQuery($tableName, $query) | ConvertFrom-Json
            if($datas) {
                foreach ($data in $datas.value) {
                    $this.deleteDataByPartitionKeyAndRowKey($tableName, $data.PartitionKey, $data.RowKey)
                }
                return $true
            } else {
                return $false
            }
        } catch {
            return $_
        }       
    }

    # Select & Remove
    [PSCustomObject]deleteDataByTable([String]$tableName) {
        try{
            $datas = $this.selectByTable($tableName) | ConvertFrom-Json
            if($datas) {
                foreach ($data in $datas.value) {
                    $this.deleteDataByPartitionKeyAndRowKey($tableName, $data.PartitionKey, $data.RowKey)
                }
                return $true
            } else {
                return $false
            }
        } catch {
            return $_
        }
    }

    [PSCustomObject]insertData([String]$tableName, [String]$jsonBody) {
        $header = $this.setAuthHeader('insertData', $tableName, '')
        if($header) {
            return Invoke-WebRequest -Uri ("https://"+ $this.storageAccount +".table.core.windows.net/" + $tableName) `
                                 -Headers $header `
                                 -Method Post `
                                 -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonBody)) `
                                 -UseBasicParsing
        } else {
            return $false
        }
    }

    [PSCustomObject]selectByQuery([String]$tableName, [String]$query) {
        $query = [System.Web.HttpUtility]::UrlPathEncode($query)
        $header = $this.setAuthHeader("selectByQuery", $tableName, $query)
        if($header) {
            return Invoke-WebRequest -Uri ("https://"+ $this.storageAccount +".table.core.windows.net/" + $tableName + "()?`$filter=" + $query) `
                                 -Headers $header `
                                 -Method Get `
                                 -UseBasicParsing
        } else {
            return $false
        }
    }

    [PSCustomObject]selectByTable([String]$tableName) {
        $header = $this.setAuthHeader("selectByTable", $tableName, '')
        if($header) {
            return Invoke-WebRequest -Uri ("https://"+ $this.storageAccount +".table.core.windows.net/" + $tableName + "()") `
                                 -Headers $header `
                                 -Method Get `
                                 -UseBasicParsing
        } else {
            return $false
        }
    }
}

enum TableOperation {
    createTable
    deleteTable
    insertData
    updateDataByPartitionKeyAndRowKey
    deleteDataByQuery
    deleteDataByTable
    deleteDataByPartitionKeyAndRowKey
    selectByQuery
    selectByTable
}

function StorageTableFromAD() {
    param(
        [PSCustomObject]$azAdInfo,
        [string]$storageAccoutResourceGroup,
        [string]$storageAccoutName
    )
    $saURL = "https://management.azure.com/subscriptions/" + 
              $azAdInfo.subscription + "/resourceGroups/" + 
              $storageAccoutResourceGroup + 
              "/providers/Microsoft.Storage/storageAccounts/" + 
              $storageAccoutName + 
              "/listKeys?api-version=2019-06-01"
    $saHeader = @{
        "Authorization"="Bearer " + $azAdInfo.token.access_token
    }              
    $saData = (Invoke-WebRequest -Method Post `
                                -Uri $saURL `
                                -Headers $saHeader -UseBasicParsing).Content | ConvertFrom-Json

    return [StorageTable]::new($storageAccoutName, $saData.keys[0].value)
}


function StorageTable() {
    param(
        [String]$storageAccount,
        [String]$key
    )
    
    return [StorageTable]::new($storageAccount, $key)
}