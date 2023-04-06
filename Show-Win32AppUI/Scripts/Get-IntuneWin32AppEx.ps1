Function Get-IntuneWin32AppEx{
[CmdletBinding()]
param()
BEGIN{
    # Ensure required authentication header variable exists
    if ($Global:AuthenticationHeader -eq $null) {
        Write-Warning -Message "Authentication token was not found, use Connect-MSIntuneGraph before using this function"; break
    } else {
        $TokenLifeTime = ($Global:AuthenticationHeader.ExpiresOn - (Get-Date).ToUniversalTime()).TotalMinutes
        if ($TokenLifeTime -le 0) {
            Write-Warning -Message "Existing token found but has expired, use Connect-MSIntuneGraph to request a new authentication token"; break
        } else {
            Write-Verbose -Message "Current authentication token expires in (minutes): $($TokenLifeTime)"
        }
    }

    # Set script variable for error action preference
    $ErrorActionPreference = "Stop"
}
PROCESS{

    Add-Type -AssemblyName System.Web
    $Filter = [System.Web.HttpUtility]::UrlEncode("(microsoft.graph.managedApp/appAvailability eq null or microsoft.graph.managedApp/appAvailability eq 'lineOfBusiness' or isAssigned eq true)")
    $URI = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$Filter=$Filter"

    Write-Verbose "URI = '$URI'"

    try{
        $Result = Invoke-RestMethod -Headers $Global:AuthenticationHeader -Uri $URI -Method Get -ErrorAction Stop
        if ($null -ne $Result.value) {
            foreach ($R in $Result.value) {
                #Write-Verbose -Message "Successfully retrieved Win32 App group with ID: $($R.id)"
                Write-Output -InputObject $R
            }
        }else{
            Write-Warning "No LOB groups found"
        }
    }catch{
        Write-Warning "Failed '$_'"
    }

}
}