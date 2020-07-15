class ARMTemplate {
    [String]$templateLocation
    [String]$requestBody
    

    [PSCustomObject]$resourceType

    [bool]setResourceType($string) {
        $types = [resourceTypes].GetEnumNames()
        if ($types.Contains($string)) {
            switch ($types) {
                'disk' { 
                    [Disk]$this.resourceType = [Disk]::new()
                    break
                }
                Default {
                    return $false
                }
            }
            return $true
        } else {
            Write-Host "There is no ${string} type of enum we have [ ${types} ]"
            return $false
        }
    }
    
    ################################################################################################################################################
    ### ARM - Disk
    [void]setArmDisk ([String]$diskName, [String]$date, [String]$diskId, [int]$diskSize, [String]$sku_name, [String]$sku_tier, [String]$osType) {
        if($diskName.Length -ge 40) {
            $this.resourceType.diskName = $diskName.Substring(0,40) + "-" + $date
        } else {
            $this.resourceType.diskName = $diskName + "-" + $date
        }
        $this.resourceType.diskParam = '
            "snapshots_Name": {
                "value" : "' + ($this.resourceType.diskName) + '"
            },
            "sourceDiskID": {
                "value" : "' + $diskId + '"
            },
            "diskSizeGB": {
                "value" : ' + $diskSize + '
            },
            "sku_name": {
                "value" : "' + $sku_name + '"
            },
            "sku_tier": {
                "value" : "' + $sku_tier + '"
            },
            "osType": {
                "value" : "' + $osType + '"
            }
        '
        if ($osType) {
            $this.templateLocation = "https://raw.githubusercontent.com/chupark/ArmTemplate/master/Disk/diskSnapshot_OS.json"
        } else {
            $this.templateLocation = "https://raw.githubusercontent.com/chupark/ArmTemplate/master/Disk/diskSnapshot_data.json"
        }
    }
    ### ARM - Disk
    ################################################################################################################################################


    [String]getRequestBody() {
        $this.requestBody = '
                    {
                        "properties": {
                            "templateLink": {
                            "uri": "' + $this.templateLocation + '"
                            },
                            "parameters": {' + $this.resourceType.diskParam + '},
                            "mode": "Incremental "
                        }
                    }
                '
        return $this.requestBody.Trim()
    }
}

Class Disk {
    [String]$diskParam
    [String]$diskName
}

enum resourceTypes {
    disk
}

function GetARMTemplate() {
    return [ARMTemplate]::new()
}
