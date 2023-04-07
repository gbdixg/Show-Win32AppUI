# Show-Win32AppUI

GUI front-end for end-to-end creation of Intune Win32 apps using the IntuneWin32App module

![Show-Win32AppUI](/Show-Win32AppUI.gif)

This isn't a one-size-fits-all community tool. You will likely need to modify it to meet your needs. However, its written in PowerShell and has code comments and blog posts to make editing simpler.

# SETUP

## Modules

*Show-Win32AppUI* depends on two PowerShell modules. Install these modules if you don't already have them.  

```PowerShell
Install-Module -Name MSAL.PS
Install-Module -Name IntuneWin32App
```

The most recent tested versions are listed below:

```PowerShell
Install-Module -Name MSAL.PS -RequiredVersion 4.37.0.0
Install-Module -Name IntuneWin32App -RequiredVersion 1.4.0
```

## Tenant ID

Update the $TenantID on line 4 of *Show-Win32AppUI.ps1* to use your required Azure tenant. Your tenant ID is available from the [Azure AD portal](https://aad.portal.azure.com/) *Overview* page.
  
## Azure Client App

An Azure Client App is used with interactive authentication to access the Microsoft Graph. There are two setup steps required:

1. **Specify the Azure application**  
By default, the tool will use the built-in *Microsoft Graph PowerShell* enterprise application. However, I recommend creating a custom Azure app in your own tenant. A step by step guide to creating a custom app is available [here](http://localhost)

> If using a custom app, update *Show-Win32AppUI.ps1* to set the $ClientID variable on line 6 to match the client ID (a.k.a Application ID) of your app.


2. **Consent to the required permissions on behalf of your tenant**  
Whether you use a custom app or Microsoft Graph PowerShell, the app must be configured with the required API permissions and consent must be granted. The **delegated** permissions are listed below. A step by step for setting these permissions can be found in the second part of [this article](http://localhost).  

- Directory.AccessAsUser.All  
- DeviceManagementApps.ReadWrite.All  
- Group.ReadWrite.All  
- GroupMember.ReadWrite.All  
- User.Read

## User permissions

*Delegated consent* uses the intersection of application permissions and user permissions to authorise access. i.e. the authenticated user must have the required permissions as well as the application. When using the app, authenticate using an Azure account with *one* of the following roles:

- Intune Administrator
- Global Administrator

## Workstation permissions

The tool does not need administrative access to the client workstation. Internet access is required, to download the [Win32 Content Prep tool](https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool) on first use.

## PowerShell script execution

PowerShell script execution is disabled on Windows clients by default. Use one of the methods below to allow script execution on the workstation.

```PowerShell
set-executionpolicy Unrestricted
```

or

```CMD
powershell -executionpolicy bypass -file <path to script>
```

# Launch the tool

Start a PowerShell 5.1 or Pwsh 7.x console and execute the script as follows:

```PowerShell
.\Show-Win32AppUI.ps1
```

To show debug information in the console add the *WriteHost* switch:

```PowerShell
.\Show-Win32AppUI.ps1 -WriteHost
```
# More information

See this [Blog post](http://localhost) and linked articles for more information  
<br>

# Credits

- Show-Win32AppUI is a front-end to the excellent [IntuneWin32App module](https://github.com/MSEndpointMgr/IntuneWin32App). Full credit to the contributors of this project.

- The [MSAL.PS module](https://github.com/AzureAD/MSAL.PS) has simplified the transition from ADAL to MSAL authentication.

- [Boe Prox](https://learn-powershell.net/) for PowerShell Runspace tips

- [SMSAgent](https://smsagent.blog/blog-posts/) for PowerShell WPF tips

