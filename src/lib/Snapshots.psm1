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
        try{
            $req = Invoke-WebRequest -Headers $this.header -Uri ("https://management.azure.com/subscriptions/" + 
                                                            $this.azAdInfo.subscription + 
                                                            "/resourcegroups/" + 
                                                            $diskResourceGroup + 
                                                            "/providers/Microsoft.Resources/deployments/" + 
                                                            $deploymentName + 
                                                            "?api-version=2019-10-01") `
                                    -Body ([System.Text.Encoding]::UTF8.GetBytes($armTemplate)) `
                                    -Method Put
            return $req
        } catch {
            return $_
        }
    }
    <#
    [PSCustomObject]grantAccessURL([int]$durationInSeconds, [String]$diskResourceGroup, [String]$diskName) {
        $body = '{
            "access": "Read",
            "durationInSeconds": ' + $durationInSeconds + '
        }'
        $accessheader = @{
            "Authorization"="bearer " + $this.azAdInfo.token.access_token
            "Content-Type"="application/json"
        }
        $requestGrantAccess = Invoke-WebRequest -Method Post `
                                                -Uri ("https://management.azure.com/subscriptions/" + 
                                                      $azAdInfo.subscription + 
                                                      "/resourceGroups/" + 
                                                      $diskResourceGroup + 
                                                      "/providers/Microsoft.Compute/snapshots/" + 
                                                      $diskName + 
                                                      "/beginGetAccess?api-version=2019-07-01") `
                                                -Headers $accessheader `
                                                -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
        
        $promise = Invoke-WebRequest -Method Get `
                                    -Headers $accessheader `
                                    -Uri ($requestGrantAccess.Headers.'Azure-AsyncOperation'[0])
    }
    #>

}



function LoadDiskSnapshots() {
    param(
        [PSCustomObject]$azAdInfo
    )
    return [DiskSnapshots]::new($azAdInfo)
}
