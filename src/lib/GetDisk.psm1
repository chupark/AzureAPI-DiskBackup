## Constructor
Class DiskInfo {
    [String]$vmName
    [String]$vmResourceGroup
    [String]$location
    [String]$diskName
    [String]$lun
    [String]$diskResourceGroup
    [String]$diskType
    [String]$osType
    [String]$diskId
    [String]$diskSize
    [String]$sku_name
    [String]$sku_tier
}

## Get Disk Imformation
Class ManagedDisk {
    [string]$subscription
    [PSCustomObject]$header
    [PSCustomObject[]]$disks

    ManagedDisk([PSCustomObject]$azAdInfo) {
        $this.subscription = $azAdInfo.subscription
        $this.header = @{
            "Authorization" = "bearer " + $azAdInfo.token.access_token
        }
    }

    [PSCustomObject]getManagedDiskByName($resourceGroup, $diskName) {
        $url = "https://management.azure.com/subscriptions/" +
                $this.subscription + 
                "/resourceGroups/" +
                $resourceGroup +
                "/providers/Microsoft.Compute/disks/" + 
                $diskName + 
                "?api-version=2019-07-01"
        $result = Invoke-WebRequest -Headers $this.header -Uri $url -UseBasicParsing
        ## valid here
        $result = $result | ConvertFrom-Json
        return ,$result
    }    

    [PSCustomObject]getManagedDiskbyID($resourceIDs, $lun) {
        $null = $resourceIDs -match "/resourceGroups/(?<resourceGroup>.+)/providers/Microsoft.Compute/disks/(?<diskName>.+)"
        $url = "https://management.azure.com/subscriptions/" +
                $this.subscription + 
                "/resourceGroups/" +
                $Matches.resourceGroup +
                "/providers/Microsoft.Compute/disks/" + 
                $Matches.diskName + 
                "?api-version=2019-07-01"
        $result = Invoke-WebRequest -Headers $this.header -Uri $url -UseBasicParsing

        ## valid here
        $result = $result | ConvertFrom-Json
        $this.addDisk($result, $lun)

        return ,$result
    }

    [PSCustomObject]getManagedDiskbyIDwithGetVM($resourceIDs, $lun) {
        $null = $resourceIDs -match "/resourceGroups/(?<resourceGroup>.+)/providers/Microsoft.Compute/disks/(?<diskName>.+)"
        $url = "https://management.azure.com/subscriptions/" +
                $this.subscription + 
                "/resourceGroups/" +
                $Matches.resourceGroup +
                "/providers/Microsoft.Compute/disks/" + 
                $Matches.diskName + 
                "?api-version=2019-07-01"
        $result = Invoke-WebRequest -Headers $this.header -Uri $url -UseBasicParsing

        ## valid here
        $result = $result | ConvertFrom-Json
        $this.addDisk($result, $lun)

        return ,$result
    }

    [void]addDisk($result, $lun) {
        ## Valid Here
        $null = $result.managedBy -match "resourceGroups/(?<resourceGroup>.+)/providers/Microsoft.Compute/virtualMachines/(?<vmName>.+)"
        $tmpVmName = $matches.vmName
        $tmpVmResourceGroup = $matches.resourceGroup

        ## Valid Here Too
        $null = $result.id -match "/resourceGroups/(?<resourceGroup>.+)/providers/Microsoft.Compute/disks/(?<diskName>.+)"
        $tmpDiskName = $matches.diskName
        $tmpDiskResourceGroup = $matches.resourceGroup

        [DiskInfo]$diskInfo = [DiskInfo]::new()
        $diskInfo.vmName = $tmpVmName
        $diskInfo.vmResourceGroup = $tmpVmResourceGroup
        $diskInfo.location = $result.location
        if ($result.properties.osType) {
            $diskInfo.diskType = "os"
            $diskInfo.osType = $result.properties.osType
        } else {
            $diskInfo.diskType = "data"
            $diskInfo.osType = ""
        }
        $diskInfo.diskName = $tmpDiskName
        $diskInfo.lun = $lun
        $diskInfo.diskResourceGroup = $tmpDiskResourceGroup
        $diskInfo.diskId = $result.id
        $diskInfo.diskSize = $result.properties.diskSizeGB
        $diskInfo.sku_name = $result.sku.name
        $diskInfo.sku_tier = $result.sku.tier

        $this.disks += $diskInfo
    }

    [void]cleanDiskList() {
        $this.disks = $null
    }

    [PSCustomObject]getDiskList() {
        return $this.disks | Select-Object -Unique
    }

}


function GetDiskInformation() {
    param(
        [PSCustomObject]$azAdInfo
    )
    return [ManagedDisk]::new($azAdInfo)
}
