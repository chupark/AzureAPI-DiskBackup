Import-Module -Name .\SetAzAD.psm1 -Force

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
        $this.vmInfo.osDisk = $result.properties.storageProfile.osDisk.managedDisk.Id
        $this.vmInfo.dataDisks = $result.properties.storageProfile.dataDisks.managedDisk.Id
        $this.vmInfo.networkInterfaces = $result.properties.networkProfile.networkInterfaces.Id
        $this.vmInfo.location = $result.location
        $this.vmName = $result.Name
        return ,$result
    }
}

Class VMInfo {
    [String]$location
    [String]$osDisk
    [Array]$dataDisks
    [Array]$networkInterfaces
}

Class DiskInfo {
    
}

function GetVmInformation() {
    param(
        [PSCustomObject]$azAdInfo
    )
    return [VirtualMachine]::new($azAdInfo)
}
