Function Find-AADUser{
[CmdletBinding()]
param(
    [parameter(position=0,ValueFromPipeLine,ValueFromPipeLineByPropertyName,Mandatory)]
    [Alias('displayName','surname','givenName','sn')]
    [ValidateNotNullOrEmpty()]
    [String]$ANR
)
BEGIN{
    # Ensure required authentication header variable exists
    if ($Global:AuthenticationHeader -eq $null) {
        Write-TxtLog "Authentication token was not found, use Connect-MSIntuneGraph before using this function" -severity WARN; break
    } else {
        $TokenLifeTime = ($Global:AuthenticationHeader.ExpiresOn - (Get-Date).ToUniversalTime()).TotalMinutes
        if ($TokenLifeTime -le 0) {
            Write-TxtLog "Existing token found but has expired, use Connect-MSIntuneGraph to request a new authentication token" -severity WARN; break
        } else {
            Write-TxtLog "Current authentication token expires in (minutes): $($TokenLifeTime)"
        }
    }

    Add-Type -AssemblyName System.Web

}
PROCESS{

    Remove-variable 'output' -force -ErrorAction SilentlyContinue
    $Filter = "startswith(userprincipalName,'$([System.Web.HttpUtility]::UrlEncode($ANR))')"

    $URI = "https://graph.microsoft.com/v1.0/users?`$Filter=$Filter"
    Write-TxtLog "Search URI - '$URI'" -indent 1
    $output = @()
    
    try{
        $QueryResult = Invoke-RestMethod -Headers $Global:AuthenticationHeader -Uri $URI -Method Get -ErrorAction Stop
        if($QueryResult.Value.Count -gt 0){

            $Output=@($QueryResult.Value)
            
            While($null -ne $QueryResult."@odata.nextLink"){
                $QueryResult = Invoke-RestMethod -Headers $Global:AuthenticationHeader -Uri  $QueryResult."@odata.nextLink" -Method Get
                if($QueryResult.Value.Count -gt 0){
                    $output+=$QueryResult.Value
                }
            }
        }
        
    }catch{
       Write-TxtLog "Error '$_'" -severity ERROR -indent 2
    }finally{
        # Prevent array unroll
        ,$output
    }

}
}