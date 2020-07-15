class VirtualMachine {
    [string]$subscription
    [String]$vmName
    [PSCustomObject]$header

    [VMInfo]$vmInfo = [VMInfo]::new()
    
    VirtualMachine([PSCustomObject]$azAdInfo) {
        $this.subscription = $azAdInfo.subscription
        $this.header = @{
            "Authorization" = "bearer " + $azAdInfo.token.access_token
        }
    }

    [PSCustomObject]getVirtualMachine($resourceGroup, $vmName) {
        $url = "https://management.azure.com/subscriptions/" +
                $this.subscription + 
                "/resourceGroups/" +
                $resourceGroup +
                "/providers/Microsoft.Compute/virtualMachines/" + 
                $vmName + 
                "?api-version=2019-12-01"
        $result = Invoke-WebRequest -Headers $this.header -Uri $url
        ## valid here
        $result = $result | ConvertFrom-Json

        ## OsDisk
        $this.vmInfo.networkInterfaces = $result.properties.networkProfile.networkInterfaces.Id
        $this.addDisk($result.properties.storageProfile.osDisk.managedDisk.Id, "os", "")
        foreach($dataDisk in $result.properties.storageProfile.dataDisks) {
            $this.addDisk($dataDisk.managedDisk.Id, "data", $dataDisk.lun)
        }
        $this.vmInfo.location = $result.location
        $this.vmName = $result.Name
        return ,$result
    }

    [void] addDisk([String]$diskId, [String]$diskType, [String]$lun) {
        [DiskInfo]$diskInfo = [DiskInfo]::new()
        $diskInfo.diskId = $diskId
        $diskInfo.diskType = $diskType
        $diskInfo.lun = $lun
        $this.vmInfo.disks += $diskInfo
    }

    [void] cleanVMInfo() {
        $this.vmInfo = [VMInfo]::new()
    }
}

Class VMInfo {
    [String]$location
    [PSCustomObject[]]$disks
    [Array]$networkInterfaces
}

Class DiskInfo {
    [String]$diskId
    [String]$diskType
    [String]$lun
}

function GetVmInformation() {
    param(
        [PSCustomObject]$azAdInfo
    )
    return [VirtualMachine]::new($azAdInfo)
}
