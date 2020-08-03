Class DiskSnapshots {
    [PSCustomObject]$azAdInfo
    hidden $date
    hidden [String]$storageDateFormat
    hidden [PSCustomObject]$header

    DiskSnapshots([PSCustomObject]$azAdInfo) {
        $this.date = Get-Date
        $this.azAdInfo = $azAdInfo
        $this.setDateTime()
        $this.header = @{
            "Authorization"="bearer " + $azAdInfo.token.access_token
            "Content-Type"="application/json"
        }
    }

    [void]setDateTime() {
        $this.storageDateFormat = Get-Date -Date ($this.date.ToUniversalTime()) -Format 'yyyy-MM-ddTHH:mm:ssZ'
    }

    [PSCustomObject]createDiskSnapshotWithARM($diskResourceGroup, [String]$armTemplate, $deploymentName) {
            $uri = "https://management.azure.com/subscriptions/{0}/resourcegroups/{1}/providers/Microsoft.Resources/deployments/{2}?api-version=2019-10-01" -f $this.azAdInfo.subscription, $diskResourceGroup, $deploymentName
        try{
            $req = Invoke-WebRequest -Headers $this.header -Uri $uri `
                                     -Body ([System.Text.Encoding]::UTF8.GetBytes($armTemplate)) `
                                     -Method Put `
                                     -UseBasicParsing
            return $req
        } catch {
            return $_
        }
    }

    [PSCustomObject]grantAccessURL([int]$durationInSeconds, [String]$diskResourceGroup, [String]$diskName) {
        $body = '{
            "access": "Read",
            "durationInSeconds": ' + $durationInSeconds + '
        }'
        $uri = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Compute/snapshots/{2}/beginGetAccess?api-version=2019-07-01" -f $this.azAdInfo.subscription, $diskResourceGroup, $diskName
        $requestGrantAccess = Invoke-WebRequest -Method Post `
                                                -Uri $uri `
                                                -Headers $this.header `
                                                -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
                                                -UseBasicParsing
        return $requestGrantAccess
    }

    [PSCustomObject]revokeAccessURL([String]$diskResourceGroup, [String]$diskName) {
        $uri = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Compute/snapshots/{2}/endGetAccess?api-version=2019-07-01" -f $this.azAdInfo.subscription, $diskResourceGroup, $diskName
        $requestRevokeAccess = Invoke-WebRequest -Method Post `
                                                 -Uri $uri `
                                                 -Headers $this.header `
                                                 -UseBasicParsing
        return $requestRevokeAccess                                    
    }


    [PSCustomObject]getSnapshot([String]$diskResourceGroup, [String]$diskName) {
        $uri = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Compute/snapshots/{2}?api-version=2019-07-01" -f $this.azAdInfo.subscription, $diskResourceGroup, $diskName
        $snapshot = Invoke-WebRequest -Method Get `
                                      -Uri $uri `
                                      -Headers $this.header `
                                      -UseBasicParsing
        return $snapshot
    }
    
}



function LoadDiskSnapshots() {
    param(
        [PSCustomObject]$azAdInfo
    )
    return [DiskSnapshots]::new($azAdInfo)
}
