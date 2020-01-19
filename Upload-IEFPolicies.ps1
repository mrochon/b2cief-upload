function Upload-IEFPolicies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$clientId,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$clientsecret,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$configurationFilePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$sourceDirectory
    )

    Add-Type -AssemblyName System.Web

    # Register this script as a confidential client (web app) in your B2C tenant using the regular, non-B2C blade, App Registrations (legacy):
    #  1. Paste its Application Id into $clientId below
    #  2. Create a secret for the app and paste it into the $clientSecret below
    #  3. Grant it one Api Permission: Microsoft Graph->Application permission->Read and write your organization's trust framework policies
    #
    # If you are planning on using the script to upload your IEF policies to multiple B2C tenants (dev, qa, etc) 
    # mark the app as multi-tenant (allows signin from multiple tenants).
    # 
    # To grant this app permission in each tenant, a user with tenant admin permissions will need to grant admin consent using the following URL:
    # 
    # https://login.microsoftonline.com/<yourtenant>.onmicrosoft.com/oauth2/authorize?client_id=<appId>&response_mode=form_post&response_type=code&state=abc&nonce=xyz
    # 

    if ($sourceDirectory.EndsWith('\')) {
        $sourceDirectory = $sourceDirectory + '*' 
    } else {
        if (-Not $sourceDirectory.EndsWith('\*')) { 
            $sourceDirectory = $sourceDirectory + '\*' 
        }
    }

    $clientSecret = [System.Web.HttpUtility]::UrlEncode($clientSecret)
    # $s = ConvertTo-SecureString $clientSecret -AsPlainText -force

    # upload policies whose base id is given
    function Upload-Children($baseId) {
        foreach($p in $policyList) {
            if ($p.BaseId -eq $baseId) {
                "Uploading: {0}" -f $p.Id
                $policy = $p.Body -replace "yourtenant", $env.TenantName
                $policy = $policy -replace "ProxyIdentityExperienceFrameworkAppId", $env.ProxyIdentityExperienceFrameworkAppId
                $policy = $policy -replace "IdentityExperienceFrameworkAppId", $env.IdentityExperienceFrameworkAppId
                $policy = $policy.Replace('PolicyId="B2C_1A_', 'PolicyId="B2C_1A_{0}' -f $env.PolicyPrefix)
                $policy = $policy.Replace('/B2C_1A_', '/B2C_1A_{0}' -f $env.PolicyPrefix)
                $policy = $policy.Replace('<PolicyId>B2C_1A_', '<PolicyId>B2C_1A_{0}' -f $env.PolicyPrefix)
                # replace other placeholders

                $policyId = $p.Id.Replace('_1A_', '_1A_{0}' -f $env.PolicyPrefix)
                $url = 'https://graph.microsoft.com/beta/trustFramework/policies/{0}/$value' -f $policyId
                $uploadResponse = Invoke-WebRequest $url -Body $policy -Method 'PUT' -ContentType 'application/xml' -Headers $headers
                $result = '      Result: {0} - {1}' -f $uploadResponse.StatusCode, $uploadResponse.StatusDescription
                $result
                Upload-Children $p.Id
            }
        }
    }

    # load originals
    $files = Get-Childitem -Path $sourceDirectory -Include *.xml
    $policyList = @()
    foreach($policyFile in $files) {
        $policy = Get-Content $policyFile
        $xml = [xml] $policy
        $policyList= $policyList + @(@{ Id = $xml.TrustFrameworkPolicy.PolicyId; BaseId = $xml.TrustFrameworkPolicy.BasePolicy.PolicyId; Body = $policy})
    }
    "Source policies:"
    foreach($p in $policyList) {
        "Id: {0}; Base:{1}" -f $p.Id, $p.BaseId
    }

    $conf = Get-Content -Path $configurationFilePath | Out-String | ConvertFrom-Json
    foreach($env in $conf.Environments) {
        $tenant = $env.TenantName
        $body = "grant_type=client_credentials&scope=https://graph.microsoft.com/.default&client_id=$clientId&client_secret=$clientSecret"
        $LoginResponse = Invoke-WebRequest "https://login.microsoftonline.com/$tenant.onmicrosoft.com/oauth2/v2.0/token" -Body $Body -Method 'POST' -ContentType 'application/x-www-form-urlencoded'
        $tokens = $loginResponse.Content | ConvertFrom-Json
        $access_token = $tokens.access_token
        $headers = @{Authorization = "Bearer $access_token"}  

        'Generating ' + $env.Name
        Upload-Children($null)
    }
}
