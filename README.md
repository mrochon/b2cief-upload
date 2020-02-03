# PowerShell to configure and upload a set of B2C IEF policies
PowerShell script which:
1. Modifies a set of IEF policies using values from a configuration file
2. Uploads the files to one or more B2C tenants

# Setup

## Application registration
Register the script as an application using the **Azure AD blade** (not B2C) blade of your B2C tenant:
1. Application type: web application (OAuth2 confidential client)
2. Create a secret for the application and note it down
2. Required Permissions: Microsoft Graph: Application permission: Read and write organization's trust framework policies
3. Mark the application as multi-tenant if you want to use the script with multiple B2C tenants

To complete the registration have a user with admin rights grant consent to the requested permission. If you are planning
to use this script with multiple B2C tenants, you can ask the admin to use the following url to initiate the consent process for
each tenant:

`https://login.microsoftonline.com/<yourtenant>.onmicrosoft.com/oauth2/authorize?client_id=<appId>&response_mode=form_post&response_type=code&state=abc&nonce=xyz`

Replace *yourtenant* with the name of a B2C tenant and *clientId* with the Application Id from step 1 in the above process. 

## Policy setup
1. Store your policies in a single folder. (The SampleData folder on this github project was downloaded from the [starter pack](https://github.com/Azure-Samples/active-directory-b2c-custom-policy-starterpack) for local acounts).
2. Modify the sampleData/appSettings.json file to include the values you need to replace in the policies. Use multiple Environment objects
to update multiple B2C directories.

The script will use the following string replacement rules to apply your *appSettings.json* values.

| appSettings property | String replaced in policy |
| -------- | ------ |
| TenantName | *yourtenant*. Also used to determine which B2C tenant to upload the policies to |
| PolicyPrefix | Inserted into the name of policies, e.g. *B2C_1A_MyTrustBase* where *My* is the value of the PolicyPrefix |
| ProxyIdentityExperienceFrameworkAppId | See [IEF applications setup](https://docs.microsoft.com/en-us/azure/active-directory-b2c/active-directory-b2c-get-started-custom?tabs=applications#register-identity-experience-framework-applications) |
| IdentityExperienceFrameworkAppId | See [IEF applications setup](https://docs.microsoft.com/en-us/azure/active-directory-b2c/active-directory-b2c-get-started-custom?tabs=applications#register-identity-experience-framework-applications) |
| *other* | You can define your own symbolic properties, e.g. *"CheckPlayerAPIUrl": "https://myapi.com"*. If you do, modify the PowerShell script to use the value of the property as replacement in policies with an appropriate rule to select which text should be replacedg. Look for *{CheckPlayerAPIUrl}* string in both the *TrustFrameworkExtensions.xml* and the *Upload-IEFPolicies.ps1* script to see an example |

## Execution

```$clientId = 'e.g. 3d22610c-9e4d-48ca-9c85-f4daf3564dc1'
$clientSecret = 'e.g. JvrblahblahD6pQ=
$confFile = 'C:\LocalAccounts\appSettings.json'
$source = 'C:\LocalAccounts
$dest = 'C:\LocalAccounts\updated```

`Upload-IEFPolicies -clientId $clientId -clientSecret $clientSecret -configurationFilePath $confFile -sourceDirectory $source -updatedSourceDirectory $dest`

(For better security, particularly if using the script for updating multiple B2C tenants, use X509 as credential. You will need to modify the script of course)

Where:
- clientId is the Application Id from application registration step
- clientSecret is the Application Key from application registration step
- confFile is the location of your appSettings.json file
- source is the directory containing your IEF policies
- dest (optional) is the directory where the script should save copies of modified and uploaded policies


