<#
.SYNOPSIS
	Win32 App uninstall script for %DisplayName%
    Created from MSI wrapper template
.NOTES
	Latest update %Date%
#>
[cmdletbinding()]
param()
BEGIN{

    #REGION -----Child Functions-----

    Function Write-TxtLog {
        [cmdletBinding()]
        param(
            [Parameter(Position = 0, Mandatory = $True, Helpmessage = "The text to write into the log")]
            [string]$Message
            ,
            [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
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
            Write-warning "Logfile path is not set. Use Set-LogPath or specify on the command line."
            return
        }

        $logFile = [Environment]::ExpandEnvironmentVariables($logFile)

        # Exit function if severity is less than loglevel
        $Severities = @('DEBUG', 'INFO', 'WARN', 'ERROR')
        $SeverityLevel = [array]::IndexOf($Severities, $Severity)
        if ($SeverityLevel -lt $LogLevel) { return }

        # Get calling function or script
        $CallStack = Get-PSCallStack
        try {
            $CallingFunction = if ($CallStack[1].Command.Length -le 25) {
                $CallStack[1].Command
            } else {
                ($CallStack[1].Command).subString(0, 25)
            }
        } catch {
            $CallingFunction = "Write-Log"
        }

        # e.g. 2018-06-12 09:41:21:652+01
        $DateFormat = $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss:fffzz')

        # Default is no indent, 1 = '   >', 2 = '      >>' etc
        $IndentText = "{0}{1}" -f $("   " * $Indent), $(">" * $Indent)

        # DateTime, Computername,Severity, ProcessID, CallingFunction, Message
        $MessageOut = "[{0}][{1}][{2}][{3}][{4}] {5} {6}" -f $DateFormat, $($env:COMPUTERNAME), $($Severity.ToUpper().PadRight(5)), $($PID.ToString().PadRight(6)), $($CallingFunction.ToUpper().PadLeft(25)), $IndentText, $Message

        # Console Output
        if ($WriteHost) {
            $Colours = @{
                'DEBUG' = 'WHITE'
                'INFO'  = 'WHITE'
                'WARN'  = 'YELLOW'
                'ERROR' = 'RED'
            }
            $ForeColour = $Colours[$Severity]
            Write-Host $MessageOut -ForegroundColor $ForeColour
        }

        Add-Content -LiteralPath "$logFile" -Value $MessageOut -Force -WhatIf:$false -ErrorAction SilentlyContinue


    } #EndFunction

    Function Remove-TagFile{
        param(
            [string]$DetectionFilePath
        )

        Write-TxtLog "Removing tag file '$DetectionFilePath'..."
        if(Test-path -path $DetectionFilePath){
            	
            Try{
                Remove-Item -Path $DetectionFilePath -Force -errorAction Stop
                Write-TxtLog  "Success" -indent 1
            }catch{
                Write-TxtLog  "Failed - '$_'" -indent 1 -severity ERROR
            }

        }else{
            Write-TxtLog "File was not found" -Indent 1 -Severity ERROR

        } 

    } #End Function

    Function Start-Uninstall{
	    param(
		    [string]$ExePath
		    ,
		    [string]$ExeArgs
            ,
            [string]$PackageName
	    )

        if($ExeArgs -notmatch '/l'){
            $ExeArgs+=" /l*v $($env:windir)\Temp\$($PackageName)_MSI_Uninstall.log"
        }
	   
        try{
            Write-TxtLog "Running '$ExePath $ExeArgs'" -Indent 1
            $Result = Start-Process $ExePath -ArgumentList $ExeArgs -Wait -PassThru -ErrorAction Stop

            Write-TxtLog "Completed with return code '$($Result.Exitcode)'" -Indent 2
            $output = $Result.ExitCode
        }catch{
            Write-TxtLog "Failed with error '$_'" -Indent 2 -Severity ERROR
            $output = 1
        }

        $output

	   
    } # End Function

    #ENDREGION

}

PROCESS{

    ################## VARIABLES ####################

    $DisplayName = '%DisplayName%'
    $Publisher = '%Publisher%' 
    $AppName = '%AppName%'
    $Version = '%Version%'
    $PackageName = '%PackageName%'
    $DetectionFilePath = '%DetectionFilePath%'

    $SetupFile = '%UninstallFile%'
    $SetupArgs = '%UninstallArgs%'
    $ProductCode = '%ProductCode%'

    #################################################

    $SetupFile = [Environment]::ExpandEnvironmentVariables($SetupFile)
    $SetupArgs = [Environment]::ExpandEnvironmentVariables($SetupArgs)

    $DetectionFilePath = [Environment]::ExpandEnvironmentVariables($DetectionFilePath)

    $LogFolder = "$([Environment]::GetEnvironmentVariable('WINDIR'))\Temp"
    $ScriptName = $($MyInvocation.MyCommand.Name)
    $Script:LogFile = "$LogFolder\$($PackageName)_$($ScriptName).log"

    Write-TxtLog "Starting script '$ScriptName' in context '$($ENV:Username)'"
    Write-TxtLog "Publisher = '$Publisher'; AppName = '$AppName'; Version = '$Version'"
    Write-TxtLog "PackageName = '$PackageName'"
    Write-TxtLog "Installer = '$SetupFile'"
    Write-TxtLog "Arguments = '$SetupArgs'"
    Write-TxtLog "ProductCode = '$ProductCode'"
    Write-TxtLog "DetectionFilePath = '$DetectionFilePath'"

    Write-TxtLog  "Running uninstall command..." 
    $Retcode = Start-Uninstall -ExePath $SetupFile -ExeArgs $SetupArgs

    Switch ($Retcode){
        0 {
            Write-TxtLog  "0 = Completed successfully" -Indent 1

            Write-TxtLog  "Removing installer detection file..."
            Remove-TagFile -DetectionFilePath $DetectionFilePath
            break
        }

        3010 {
            Write-TxtLog  "3010 = Completed successfully. Restart required" -indent 1

            Write-TxtLog  "Removing installer detection file..."
            Remove-TagFile -DetectionFilePath $DetectionFilePath
            break
        }

        1641 {
            Write-TxtLog  "1641 = Package correctly uninstalled. Installer initiated a restart" -Indent 1

            Write-TxtLog  "Removing installer detection file..."
            Remove-TagFile -DetectionFilePath $DetectionFilePath
            break
        }

        default {
            Write-TxtLog  "Unxpected return code '$Retcode'" -indent 1 -Severity ERROR
        }
	}

    Write-TxtLog  "========== FINISHED =========="
    Exit $Retcode

}

