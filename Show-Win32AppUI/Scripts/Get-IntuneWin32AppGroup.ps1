Function Get-IntuneWin32AppGroup{
[CmdletBinding()]
param(
    [parameter(position=0,ValueFromPipeLine,ValueFromPipeLineByPropertyName,Mandatory)]
    [Alias("Name")]
    [ValidateNotNullOrEmpty()]
    [String]$displayName
)
BEGIN{
    # Ensure required authentication header variable exists
    if ($Global:AuthenticationHeader -eq $null) {
        Write-Warning -Message "Authentication token was not found, use Connect-MSIntuneGraph before using this function"; break
    } else {
        $TokenLifeTime = ($Global:AuthenticationHeader.ExpiresOn - (Get-Date).ToUniversalTime()).Minutes
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

    $filter = "displayName eq '$([System.Web.HttpUtility]::UrlEncode($displayName))'"
    $URI = "https://graph.microsoft.com/v1.0/groups?`$Filter=$Filter"

    $Result = Invoke-RestMethod -Headers $Global:AuthenticationHeader -Uri $URI -Method Get -ErrorAction Stop
    if ($null -ne $Result.value) {
        foreach ($R in $Result.value) {
            Write-Verbose -Message "Successfully retrieved Win32 App group with ID: $($R.id)"
            Write-Output -InputObject $R
        }
    }else{
        Write-Warning "Group '$displayName' was not found"
    }  

}
}