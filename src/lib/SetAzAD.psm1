class SetAzAD {
    [string]$tenant
    [string]$subscription
    [PSCustomObject]$token

    SetAzAD([string]$tenant, [string]$subscription) {
        $this.tenant = $tenant
        $this.subscription = $subscription
    }

    [void]setToken([string]$grant_type, [string]$client_id, [string]$client_secret, [string]$resource) {
        $body = @{
            "grant_type"=$grant_type
            "client_id"=$client_id
            "client_secret"=$client_secret
            "resource"=$resource
        }
        $this.token = Invoke-RestMethod -Method Post -Uri ("https://login.microsoftonline.com/" + $this.tenant + "/oauth2/token") -Body $body
    }
}

function SetAzAD() {
    param(
        [string]$tenant,
        [string]$subscription
    )
    return [SetAzAD]::new($tenant, $subscription)
}
