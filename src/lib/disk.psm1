Import-Module -Name .\SetAzAD.psm1 -Force

$azAdInfo = SetAzAd -tenant '785087ba-1e72-4e7d-b1d1-4a9639137a66' -subscription 'e913dc0b-9255-46a3-b135-99c0d47161e6'
$azAdInfo.setToken('client_credentials', 'f96777d2-69e4-43ea-877a-284bdb4a3816', 'c4-NkSZ_wFU2Dc7KlD.46Y19pME-smKhkM', 'https://management.azure.com');



class DiskOperation {
    [PSCustomObject]$azAdInfo
    DiskOperation([PSCustomObject]$azAdInfo) {
        $this.azAdInfo = $azAdInfo
    }
}

<#
class Disk {
    [String]
}
#>

$header = @{
    "Authorization" = "bearer " + $azAdInfo.token.access_token
}

[DiskOperation]$diskOps
$disk = Invoke-WebRequest -Uri ("https://management.azure.com/subscriptions/" + $azAdInfo.subscription + "/resourceGroups/RG-SnapshotBackup/providers/Microsoft.Compute/disks/VM-SnapshotBackup_OsDisk_1_df07050087da4cd5b7a8d9679991dae8?api-version=2019-07-01") `
                          -Headers $header


$azAdInfo.tenant

[DiskOperation]$diskOps = [DiskOperation]::new($azAdInfo)