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
                'updateData' {
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

    hidden [PSCustomObject]deleteDataByPartitionKeyAndRowKey([String]$tableName, [String]$PartitionKey, [String]$RowKey) {
        $header = $this.setAuthHeader('deleteDataByPartitionKeyAndRowKey', $tableName, ("(PartitionKey='" + $PartitionKey + "',RowKey='" + $RowKey + "')"))
        return Invoke-WebRequest -Uri ("https://"+ $this.storageAccount +".table.core.windows.net/" + $tableName + "(PartitionKey='" + $PartitionKey + "',RowKey='" + $RowKey + "')") `
                                 -Headers $header `
                                 -Method Delete 
    }

    # Select & Remove
    [PSCustomObject]deleteDataByQuery([String]$tableName, [String]$query) {
        try{
            $datas = $this.selectByQuery($tableName, $query) | ConvertFrom-Json
            foreach ($data in $datas.value) {
                $this.deleteDataByPartitionKeyAndRowKey($tableName, $data.PartitionKey, $data.RowKey)
            }
            return ,$true
        } catch {
            return $_
        }       
    }

    # Select & Remove
    [PSCustomObject]deleteDataByTable([String]$tableName) {
        try{
            $datas = $this.selectByTable($tableName) | ConvertFrom-Json
            foreach ($data in $datas.value) {
                $this.deleteDataByPartitionKeyAndRowKey($tableName, $data.PartitionKey, $data.RowKey)
            }
            return ,$true
        } catch {
            return $_
        }
    }

    [PSCustomObject]insertData([String]$tableName, [String]$jsonBody) {
        $header = $this.setAuthHeader('insertData', $tableName, '')
        return Invoke-WebRequest -Uri ("https://"+ $this.storageAccount +".table.core.windows.net/" + $tableName) `
                                 -Headers $header `
                                 -Method Post `
                                 -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonBody))
    }

    [PSCustomObject]selectByQuery([String]$tableName, [String]$query) {
        $query = [System.Web.HttpUtility]::UrlPathEncode($query)
        $header = $this.setAuthHeader("selectByQuery", $tableName, $query)
        return Invoke-WebRequest -Uri ("https://"+ $this.storageAccount +".table.core.windows.net/" + $tableName + "()?`$filter=" + $query) `
                                 -Headers $header `
                                 -Method Get
    }

    [PSCustomObject]selectByTable([String]$tableName) {
        $header = $this.setAuthHeader("selectByTable", $tableName, '')
        return Invoke-WebRequest -Uri ("https://"+ $this.storageAccount +".table.core.windows.net/" + $tableName + "()") `
                                 -Headers $header `
                                 -Method Get
    }
}

enum TableOperation {
    createTable
    deleteTable
    insertData
    updateData
    deleteDataByQuery
    deleteDataByTable
    deleteDataByPartitionKeyAndRowKey
    selectByQuery
    selectByTable
}

function StorageTable() {
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
                                -Headers $saHeader).Content | ConvertFrom-Json

    return [StorageTable]::new($storageAccoutName, $saData.keys[0].value)
}