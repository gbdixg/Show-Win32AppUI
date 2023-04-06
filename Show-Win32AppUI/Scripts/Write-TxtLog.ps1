Function Write-TxtLog {
        [cmdletBinding()]
        param(
            [Parameter(Position = 0, Mandatory = $True, Helpmessage = "The text to write into the log")]
            [string]$Message
            ,
            [ValidateSet('VERBOSE', 'INFO', 'WARN', 'ERROR')]
            [string]$Severity = 'INFO'
            ,
            [ValidateRange(0, 5)]
            [int]$Indent = 0
            ,
            [ValidateNotNullOrEmpty()]
            [String]$logFile = $Script:logFile
            ,
            [ValidateRange(0, 3)]
            [int]$LogLevel = $Script:LogLevel
            ,
            [switch]$WriteHost = $Script:WriteHost

        )      

        if ($null -eq $LogLevel) { $LogLevel = 0 }

        if ([string]::IsNullOrEmpty($logfile)) {
            [console]::WriteLine("Logfile path is not set. Use Set-LogPath or specify on the command line.")
            return
        }

        $logFile = [Environment]::ExpandEnvironmentVariables($logFile)

        # Get calling function or script
        $CallStack = Get-PSCallStack
        try {
            # Get parent of current function
            $CallingFunction = $CallStack[1].Command
            if([string]::IsNullOrEmpty($CallingFunction)){
                $CallingFunction = $CallStack[-1].Command
            }

            # Truncate length
            if($CallingFunction.Length -gt 15) {
                $CallingFunction = $CallingFunction.subString(0, 15)
            }
            
        } catch {
            $CallingFunction = "Write-Log"
        }

        # e.g. 2018-06-12 09:41:21:652+01
        $DateFormat = $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss:fffzz')

        # Default is no indent, 1 = '   >', 2 = '      >>' etc
        $IndentText = "{0}{1}" -f $("   " * $Indent), $(">" * $Indent)

        $RunspaceID = $(([System.Management.Automation.Runspaces.Runspace]::DefaultRunSpace).id).ToString()
        $MessageOut = "[{0}][{1}][{2}][{3}][{4}] {5} {6}" -f $DateFormat, $($env:COMPUTERNAME), $($Severity.ToUpper().PadRight(7)), $RunspaceID.PadRight(4), $($CallingFunction.ToUpper().PadLeft(15)), $IndentText, $Message
           
        # Console Output
        if ($WriteHost) {
            
            $Colours = @{
                'VERBOSE' = 'CYAN'
                'INFO'  = 'WHITE'
                'WARN'  = 'YELLOW'
                'ERROR' = 'RED'
            }
            $ForeColour = $Colours[$Severity]
            [console]::ForegroundColor=$ForeColour
            [Console]::WriteLine($MessageOut)
            [console]::ResetColor()
        }
        # Use a mutex to prevent race condition on log write
        $mtx = New-Object System.Threading.Mutex($false, "LogMutex")
        If ($mtx.WaitOne()){
            try{
                Add-Content -LiteralPath "$logFile" -Value $MessageOut -Force -WhatIf:$false -ErrorAction Stop
            }catch{
                $ForeColour = 'Red'
                [Console]::WriteLine("Failed to write to debug log '$_'")
                [console]::ResetColor()

            }finally{
                [void]$mtx.ReleaseMutex()
                $mtx.Dispose()
            } 
        }
                
    } #EndFunction