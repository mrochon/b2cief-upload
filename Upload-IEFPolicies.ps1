function Upload-IEFPolicies {
    [CmdletBinding()]
    param(
        #[Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$sourceDirectory = '.\',

        [ValidateNotNullOrEmpty()]
        [string]$configurationFilePath = '.\conf.json',

        [ValidateNotNullOrEmpty()]
        [string]$updatedSourceDirectory = '.\debug\',

        [ValidateNotNullOrEmpty()]
        [string]$prefix,

        [ValidateNotNullOrEmpty()]
        [switch]$generateOnly

    )

    #Add-Type -AssemblyName System.Web

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

    $m = Get-Module -ListAvailable -Name AzureADPreview
    if ($m -eq $null) {
        "Please install-module AzureADPreview before running this command"
        return
    }
    if ($sourceDirectory.EndsWith('\')) {
        $sourceDirectory = $sourceDirectory + '*' 
    } else {
        if (-Not $sourceDirectory.EndsWith('\*')) { 
            $sourceDirectory = $sourceDirectory + '\*' 
        }
    }

    # upload policies whose base id is given
    function Upload-Children($baseId) {
        foreach($p in $policyList) {
            if ($p.BaseId -eq $baseId) {
                # Skip unchanged files
                #outFile = ""
                if (-not ([string]::IsNullOrEmpty($updatedSourceDirectory))) {
                    if(!(Test-Path -Path $updatedSourceDirectory )){
                        New-Item -ItemType directory -Path $updatedSourceDirectory
                        Write-Host "Updated source folder created"
                    }
                    if (-not $updatedSourceDirectory.EndsWith("\")) {
                        $updatedSourceDirectory = $updatedSourceDirectory + "\"
                    }
                    $envUpdatedDir = '{0}{1}' -f $updatedSourceDirectory, $b2c.TenantDomain
                    if(!(Test-Path -Path $envUpdatedDir)){
                        New-Item -ItemType directory -Path $envUpdatedDir
                        Write-Host "  Updated source folder created for " + $b2c.TenantDomain
                    }
                    $outFile = '{0}\{1}' -f $envUpdatedDir, $p.Source
                    if (Test-Path $outFile) {
                        if ($p.LastWrite -le (Get-Item $outFile).LastWriteTime) {
                            "{0}: is up to date" -f $p.Id
                            Upload-Children $p.Id
                            continue;
                        }
                    }
                }
                $msg = "{0}: uploading" -f $p.Id
                Write-Host $msg  -ForegroundColor Green 
                $policy = $p.Body -replace "yourtenant.onmicrosoft.com", $b2c.TenantDomain
                $policy = $policy -replace "ProxyIdentityExperienceFrameworkAppId", $iefProxy.AppId
                $policy = $policy -replace "IdentityExperienceFrameworkAppId", $iefRes.AppId
                $policy = $policy.Replace('PolicyId="B2C_1A_', 'PolicyId="B2C_1A_{0}' -f $prefix)
                $policy = $policy.Replace('/B2C_1A_', '/B2C_1A_{0}' -f $prefix)
                $policy = $policy.Replace('<PolicyId>B2C_1A_', '<PolicyId>B2C_1A_{0}' -f $prefix)

                # replace other placeholders, e.g. {MyRest} with http://restfunc.com. Note replacement string must be in {}
                if ($conf -ne $null) {
                    $special = @('IdentityExperienceFrameworkAppId', 'ProxyIdentityExperienceFrameworkAppId', 'PolicyPrefix')
                    foreach($memb in Get-Member -InputObject $conf -MemberType NoteProperty) {
                        if ($memb.MemberType -eq 'NoteProperty') {
                            if ($special.Contains($memb.Name)) { continue }
                            $repl = "{{{0}}}" -f $memb.Name
                            $policy = $policy.Replace($repl, $memb.Definition.Split('=')[1])
                        }
                    }
                }

                $policyId = $p.Id.Replace('_1A_', '_1A_{0}' -f $prefix)

                if (-not $generateOnly) {
                    Set-AzureADMSTrustFrameworkPolicy -Content ($policy | Out-String) -Id $policyId | Out-Null
                }

                if (-not ([string]::IsNullOrEmpty($outFile))) {
                    out-file -FilePath $outFile -inputobject $policy
                }
                Upload-Children $p.Id
            }
        }
    }

    # get current tenant data
    $b2c = Get-AzureADCurrentSessionInfo

    $iefRes = Get-AzureADApplication -Filter "DisplayName eq 'IdentityExperienceFramework'"
    $iefProxy = Get-AzureADApplication -Filter "DisplayName eq 'ProxyIdentityExperienceFramework'"

    # load originals
    $files = Get-Childitem -Path $sourceDirectory -Include *.xml
    $policyList = @()
    foreach($policyFile in $files) {
        $policy = Get-Content $policyFile
        $xml = [xml] $policy
        $policyList= $policyList + @(@{ Id = $xml.TrustFrameworkPolicy.PolicyId; BaseId = $xml.TrustFrameworkPolicy.BasePolicy.PolicyId; Body = $policy; Source= $policyFile.Name; LastWrite = $policyFile.LastWriteTime })
    }
    "Source policies:"
    foreach($p in $policyList) {
        "Id: {0}; Base:{1}" -f $p.Id, $p.BaseId
    }

    if (-not ([string]::IsNullOrEmpty($configurationFilePath))) {
        $conf = Get-Content -Path $configurationFilePath | Out-String | ConvertFrom-Json
    } else {
        $conf = $null
    }

    # now start the upload process making sure you start with the base (base id == null)
    Upload-Children($null)
}

# Creates a json object with typical settings needed by
# the Upload-IEFPolicies function.
function Get-IEFSettings {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$policyPrefix
    )

    $iefAppName = "IdentityExperienceFramework"
    if(!($iefApp = Get-AzureADApplication -Filter "DisplayName eq '$($iefAppName)'"  -ErrorAction SilentlyContinue))
    {
        throw "Not found " + $iefAppName
    } else {
        if ($iefApp.PublicClient) {
            Write-Error "IdentityExperienceFramework must be defined as a confidential client (web app)"
        }
    }

    $iefProxyAppName = "ProxyIdentityExperienceFramework"
    if(!($iefProxyApp = Get-AzureADApplication -Filter "DisplayName eq '$($iefProxyAppName)'"  -ErrorAction SilentlyContinue))
    {
        throw "Not found " + $iefProxyAppName
    } else {
        if (-not $iefProxyApp.PublicClient) {
            Write-Error "ProxyIdentityExperienceFramework must be defined as a public client"
        }
        $iefOK = $signInOk = $False
        foreach($r in $iefProxyApp.RequiredResourceAccess) {
            if ($r.ResourceAppId -eq $iefApp.AppId) { $iefOk = $true }
            if ($r.ResourceAppId -eq '00000002-0000-0000-c000-000000000000') { $signInOk = $true }
        }
        if ((-not $iefOK) -or (-not $signInOk)) {
            Write-Error 'ProxyIdentityExperienceFramework is not permissioned to use the IdentityExperienceFramework app (it must be consented as well)'
        } 
    }

    $envs = @()
    $envs += @{ 
        IdentityExperienceFrameworkAppId = $iefApp.AppId;
        ProxyIdentityExperienceFrameworkAppId = $iefProxyApp.AppId;
        PolicyPrefix = $policyPrefix  }
    $envs | ConvertTo-Json

    <#
     # 
    $iefAppName = "IdentityExperienceFramework"
    if(!($iefApp = Get-AzureADApplication -Filter "DisplayName eq '$($iefAppName)'"  -ErrorAction SilentlyContinue))
    {
        Write-Host "Creating " $iefAppName
        $myApp = New-AzureADApplication -DisplayName $iefAppName   
    }
    $iefProxyAppName = "ProxyIdentityExperienceFramework"
    if(!($iefProxyApp = Get-AzureADApplication -Filter "DisplayName eq '$($iefProxyAppName)'"  -ErrorAction SilentlyContinue))
    {
        Write-Host "Creating " $iefAppName
        $myApp = New-AzureADApplication -DisplayName $iefAppName   
    }
    #>
}