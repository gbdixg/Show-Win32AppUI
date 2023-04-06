Function Add-IntuneWin32AppGroup{
 [CmdletBinding()]
 param(
    [parameter(ValueFromPipeLineByPropertyName, Mandatory)]
    [ValidateScript({$_.length -lt 255})]
    [string]$displayName
    ,
    [parameter(ValueFromPipeLineByPropertyName)]
    [string]$description
    ,
    [parameter(ValueFromPipeLineByPropertyName)]
    [Alias("owners")]
    [ValidateScript({$_.Count -lt 20})]
    [string[]]$Owner
    ,
    [parameter(ValueFromPipeLineByPropertyName)]
    [Alias("members")]
    [ValidateScript({$_.Count -lt 20})]
    [string[]]$Member
    ,
    [parameter()]
    [Hashtable]$API = $Script:API
 )
BEGIN {
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
PROCESS {

    # If Owner specified as UPN(s), convert to graph URI
    $OwnerURI = @()
    Foreach($o in $owner){
        if ($o -match '^https://graph\.microsoft\.com/v1\.0/users/') {
            $OwnerURI+=$o
        }else{
            $filter = "userPrincipalName eq '$([System.Web.HttpUtility]::UrlEncode($o))'"
            $URI = "https://graph.microsoft.com/v1.0/users?`$Filter=$Filter"
            $Result = Invoke-RestMethod -Headers $Global:AuthenticationHeader -Uri $URI -Method Get -ErrorAction Stop

            If ($Result.value.id) {
                $OwnerURI+="https://graph.microsoft.com/v1.0/users/$($Result.value.id)"
            }else{
                Write-Warning "Owner with UPN '$owner' was not found"
            }
        }
    }

    # If Member specified as UPN(s), convert to graph URI
    $MemberURI = @()
    Foreach ($m in $Member) {
        if ($m -match '^https://graph\.microsoft\.com/v1\.0/users/') {
            $MemberURI += $m
        } else {
            $filter = "userPrincipalName eq '$([System.Web.HttpUtility]::UrlEncode($m))'"
            $URI = "https://graph.microsoft.com/v1.0/users?`$Filter=$Filter"

            $Result = Invoke-RestMethod -Headers $Global:AuthenticationHeader -Uri $URI -Method Get -ErrorAction Stop
            If ($Result.value.id) {
                $MemberURI += "https://graph.microsoft.com/v1.0/users/$($Result.value.id)"
            } else {
                Write-Warning "Owner with UPN '$owner' was not found"
            }
        }
    }

    # MailNickName is required even for non-mailenabled groups
    # Use the displayName, but there are a number of invalid characters that need to be removed
    $mailNickName = $displayName -replace '\@|\(|\)|\\|\[|\]|;|:|\.|\<|\>|,|\s','_'

    $GroupProperties = @{
        "displayName"        = $displayName
        "description"        = $description
        "mailNickname"       = $mailNickName
        "groupTypes"         = @()
        "mailEnabled"        = $false
        "securityEnabled"    = $true
    }

    if($OwnerURI.Count -gt 0){
        $GroupProperties.Add("owners@odata.bind", $OwnerURI)
    }

    if ($MemberURI.Count -gt 0) {
        $GroupProperties.Add("members@odata.bind", $MemberURI)
    }

    $URI = "https://graph.microsoft.com/v1.0/groups"
    try{
        $Result = Invoke-RestMethod -Headers $Global:AuthenticationHeader -Uri $URI -Method Post -Body ($GroupProperties | ConvertTo-Json) -ContentType "application/json; charset=utf-8" -ErrorAction Stop
    }catch{
        $Result = ([int][System.Net.HttpStatusCode]$_.Exception.Response.StatusCode)
    }
    $Result
}
}



