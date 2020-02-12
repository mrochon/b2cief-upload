# PowerShell to configure and upload a set of B2C IEF policies
PowerShell script which:
1. Modifies the xml of a set of IEF policies replacing them with values from a configuration file
2. Uploads the files to one or more B2C tenants

**Note**: this version, as opposed to an earlier one updates only a single B2C tenant at a time and no longer relies on a special 
application being registered in your tenant. You need to signin to your tenant prior to running the scripts using the AzureAD-Connect command.

# Setup

## Policy setup
1. Download the script file and execute it in a PowerSehll console to define the two functions included in it (there may be better way of doing this but I am not yet that good at PowerShell).
1. Store your policies in a single folder. (The SampleData folder on this github project was downloaded from the [starter pack](https://github.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack) for local acounts).
2. Modify the sampleData/appSettings.json file to include the values you need to replace in the policies. (you can also use the Get-IEFSettings command below to 
generate this file).

The script will use the following string replacement rules to apply your *appSettings.json* values.

| appSettings property | String replaced in policy |
| -------- | ------ |
| PolicyPrefix | Inserted into the name of policies, e.g. *B2C_1A_MyTrustBase* where *My* is the value of the PolicyPrefix. Makes it easier to handle several sets of IEF policies in the tenant |
| ProxyIdentityExperienceFrameworkAppId | See [IEF applications setup](https://docs.microsoft.com/en-us/azure/active-directory-b2c/active-directory-b2c-get-started-custom?tabs=applications#register-identity-experience-framework-applications) |
| IdentityExperienceFrameworkAppId | See [IEF applications setup](https://docs.microsoft.com/en-us/azure/active-directory-b2c/active-directory-b2c-get-started-custom?tabs=applications#register-identity-experience-framework-applications) |
| *other* | You can define your own symbolic properties, e.g. *"CheckPlayerAPIUrl": "https://myapi.com"*. If you do, modify the PowerShell script to use the value of the property as replacement in policies with an appropriate rule to select which text should be replacedg. Look for *{CheckPlayerAPIUrl}* string in both the *TrustFrameworkExtensions.xml* and the *Upload-IEFPolicies.ps1* script to see an example |

## Execution

### Get-IEFSettings

You can use the Get-IEFSettings function included in the script to create the initial contents of the settings.json file. To use it run:

```PowerShell
Connect-AzureAD -TenantId yourtenant.onmicrosoft.com
Get-IEFSettings > appSettings.json`
```

The output will be a json string of the format needed in appSettings.json. Use PowerShell pipe redirection to save it directly to a file.

Log in using a B2C account with application enumeration privileges in the tenant. The script will check your B2C tenant for the required IEF applications and save their application ids in the settings file it creates.

If you have never set up your B2C to use IEF policies you can use [my IEF setup website](https://b2ciefsetup.azurewebsites.net/) or follow [instructions provided in the official documentation](https://docs.microsoft.com/en-us/azure/active-directory-b2c/custom-policy-get-started) to do so. 

### Upload-IEFPolicies

Use *Upload-IEFPolicies* function to upload your IEF policies to one or more B2C tenants.

E.g.

```PowerShell
Connect-AzureAD -TenantId yourtenant.onmicrosoft.com
$confFile = 'C:\LocalAccounts\appSettings.json'
$source = 'C:\LocalAccounts'
$dest = 'C:\LocalAccounts\updated'

Upload-IEFPolicies  -sourceDirectory $source -configurationFilePath $confFile -updatedSourceDirectory $dest`
```
Where:

| Property name | Required | Purpose |
| -------- | ------ | ----- |
| sourceDirectory | Y | Directory path where your xml policies are stored |
| updatedSourceDirectory | N | Directory path where the policies updated by this script will be stored. Also used to prevent uploading unmodified policies |
| configurationFilePath | N | jso file with additional replacement strings. The script will match any property in this file with a string with format *{<property name>}* and replace it with the value of the property |
| generateOnly | N | If used, the script will only generate policy files but not upload them to B2C |




