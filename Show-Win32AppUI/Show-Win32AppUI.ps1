#requires -module IntuneWin32App,MSAL.PS
[cmdletBinding()]
param(
    [string]$TenantID='a004e886-a000-4ab8-9533-b28222536c8b' # Replace with your tenant ID
    ,
    [string]$ClientID='14d82eec-204b-4c2f-b7e8-296a70dab67e' # Microsoft Graph PowerShell (better to replace with a custom app)
    ,
    [string]$LogFolder = 'C:\Temp' # Debug Log
    ,
    [switch]$WriteHost
)

PROCESS{
    
    Add-Type -AssemblyName PresentationFramework
    Add-type -AssemblyName System.Windows.Forms

    . $PSScriptRoot\Scripts\Write-TxtLog.ps1

    $sb_Main = {

        #REGION -------------Variables-------------

        # Variables passed into the runspace
        $Script:ScriptRoot = $ScriptRoot
        $Global:AuthenticationHeader = $AuthenticationHeader
        $Global:AccessToken = $AccessToken
        $Global:AccessTokenTenantID = $AccessTokenTenantID
        $Script:LogFile = $Logfile
        $Script:WriteHost = $WriteHost
        $Script:TenantID = $TenantID
        $Script:ClientID = $ClientID


        Write-TxtLog "Loading modular functions" -indent 1
        
        # Extensions to the IntuneWin32App module
        # These are able to share the token and auth header because IntuneWin32App module creates these in the global scope
        . $Script:ScriptRoot\Scripts\Add-IntuneWin32AppGroup.ps1
        . $Script:ScriptRoot\Scripts\Get-IntuneWin32AppGroup.ps1
        . $Script:ScriptRoot\Scripts\Find-AADUser.ps1

        # Replacing some equivalent functions in the IntuneWin32App module because of a bug or functional issue
        . $Script:ScriptRoot\Scripts\Get-IntuneWin32AppEx.ps1
        . $Script:ScriptRoot\Scripts\Add-IntuneWin32AppAssignmentGroupEx.ps1
                
        ##############################################################################################################################################
        # Defaults you may want to change
       
        $Script:DefaultArchitecture = 'x64' # if selected arch != default arch, it is used in app name
        $Script:DefaultLanguage = 'en-gb : English (United Kingdom)' # if selected language != default language, it is used in app name
        $Script:LanguageCode = 'en-gb' # default code - should match the above
        $Script:GroupPrefix = 'APP-PRD-WIN' # Assignment groups (required, available, uninstall)
        $Script:MinimumOS = '20H2'
        $Script:Win32InstallCmd = '%Windir%\sysnative\windowspowershell\v1.0\powershell.exe -noprofile -executionpolicy bypass -file .\install.ps1' # sysnative because IME is 32bit
        $Script:Win32UninstallCmd = '%Windir%\sysnative\windowspowershell\v1.0\powershell.exe -noprofile -executionpolicy bypass -file .\uninstall.ps1' # sysnative because IME is 32bit
        $Script:initialDirectory='C:\' # used in file and folder dialogs
        ##############################################################################################################################################
        
        # Variables populated by the UI
        $Script:SourceFolder='' # source files for intunewin package
        $Script:SetupFile = '' # main app setup file in intinewin package
        $Script:InstallArgs = '' # setup arguments
        $Script:UninstallFile = '' # command to uninstall app
        $Script:UninstallArgs = '' # uninstall arguments
        $Script:ProductCode = '' # MSI product code (if MSI)
        $Script:Output_Folder='' # Where intunewin is created
        
        $Script:AppName = '' # Used to generate app diplay name
        $Script:Publisher = '' # Used to generate app diplay name and in detection file folder
        $Script:Version = '' # Used to generate app diplay name and in app properties
        $Script:PkgNum = '1' # Used to generate app diplay name and helps with supercedence if there is a package issue
        $Script:Description ='' # Freeform
        
        $Script:LogoFile = '' # Path to logo displayed in company portal

        $Script:Language = $Script:DefaultLanguage # default selection in combo box.
        $Script:Architecture = $Script:DefaultArchitecture # default selection in combo box

        # Names of assignment groups
        $Script:GroupRequired = '' 
        $Script:GroupAvailable = ''
        $Script:GroupUninstall = ''

        $Script:Owners = @() # App and group owners (max 2)

        $Script:AssignmentGroups = [hashtable]::Synchronized(@{
            Required = ''
            Available = ''
            Uninstall = ''
        }) # store object ids of created AAD assignment groups

        $Script:Win32AppID = [hashtable]::Synchronized(@{}) # store object id after Win32 app creation
        $Script:Win32Apps = [hashtable]::Synchronized(@{}) # List of existing apps used to populate combo boxes
        $Script:Dependency = ''
        $Script:Supercedence = ''
        
        $script:PageCounter=1  # Current page

        #ENDREGION

        #REGION -------------BASIC FUNCTIONS-------------

        function LoadXml ($filename) {
            $XmlLoader = (New-Object System.Xml.XmlDocument)
            $XmlLoader.Load($filename)
            return $XmlLoader
        }
        
        Function Select-Folder($initialDirectory=$Script:initialDirectory){
            # Display a folder selection dialog
            $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
            $foldername.Description = "Select a folder"
            $foldername.rootfolder = "MyComputer"
            $foldername.SelectedPath = $initialDirectory
    
            if($foldername.ShowDialog() -eq "OK")
            {
                $folder = $foldername.SelectedPath
            }
            $folder
        }
    
        Function Select-File{
            # Displays a file selection dialog
            Param (
                [string] $InitialDirectory,
                [string] $Filter
            )
            $FileDialog = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
                InitialDirectory = $InitialDirectory 
                Filter = $Filter
            }
            $FileDialog.Title = "Select a file"
            if($FileDialog.ShowDialog() -eq "OK")
            {
                $file = $FileDialog.filename
            }
            $file
        }
        
        Function Test-Page1{
            # Enable the Next button when required variables are populated

            if($Script:SourceFolder -ne '' -and $Script:SetupFile -ne '' -and $Script:Output_Folder -ne '' -and $Script:UninstallFile -ne ''){
                $UIControls.Btn_Next.IsEnabled=$True
            }else{
                $UIControls.Btn_Next.IsEnabled=$False
            }
        }
    
        Function Test-Page2{
            # Enable the Next button when required variables are populated
            if($Script:AppName -ne '' -and $Script:Publisher -ne '' -and $Script:PkgNum -ne '' -and $Script:Version -ne '' -and $Script:Description -ne '' -and -not($Script:Win32Apps.ContainsKey($UIControls.txt_DisplayName.Text))){
                $UIControls.Btn_Next.IsEnabled=$True
            }else{
                $UIControls.Btn_Next.IsEnabled=$False
            }
        }

        Function Test-Page3{
            # Enable the Next button when required variables are populated

            if(($Script:Owners).Count -gt 0){
                $UIControls.Btn_Next.IsEnabled=$True
            }else{
                $UIControls.Btn_Next.IsEnabled=$False
            }
        }
    
        Function Resolve-String{
            # Get-MSIMetaData in the IntuneWin32App module seems to return an array with only the last item populated. 
            # This function extracts the last item if an array
            param(
                $data
            )
            $output = ''
            if($data -is [array]){
                $output = $data[-1]
            }else{
                $output = $data
            }
    
            if($output -is [string]){
                $output = $output.trim()
            }
            $output
        }
    
        Function Get-SetupInfo{
            # Read the setup file to get initial app info to help populate UI
            param(
                [string]$Path
            )
            PROCESS{
                Write-TxtLog "Getting file properties for '$Path'"
                if($Path.EndsWith('.msi','InvariantCultureIgnoreCase')){
                    Write-TxtLog "Getting MSI properties..."
                    # Setup file is an MSI
                    try{
                        $Script:AppName = Resolve-String -data $(Get-MSIMetaData -Path $Path -Property ProductName -WarningAction SilentlyContinue)
                        $Script:Publisher = Resolve-String -data $(Get-MSIMetaData -Path $Path -Property Manufacturer -WarningAction SilentlyContinue)
                        $Script:Version = Resolve-String -data $(Get-MSIMetaData -Path $Path -Property ProductVersion -WarningAction SilentlyContinue)
                        $Script:ProductCode = Resolve-String -data $(Get-MSIMetaData -Path $Path -Property ProductCode -WarningAction SilentlyContinue)
                        Write-TxtLog "Success" -indent 1
                    }catch{
                        Write-TxtLog "Failed '$_'" -indent 1 -severity ERROR
                    }

                    Write-TxtLog "Checking for MST..."
                    $MST = Get-ChildItem -path $(Split-Path -path $Path -parent) -Filter *.mst | Select-Object -f 1 -ExpandProperty Name
                    if($MST){
                        Write-TxtLog "Found an MST '$MST'" -indent 1
                        $Script:InstallArgs = "TRANSFORMS=`"$MST`" /q" # logging is added in the script wrapper
                        $UIControls.txt_InstallArgs.Text = $Script:InstallArgs
                    }else{
                        Write-TxtLog "No MST found" -indent 1
                    }

                }elseif($Path.EndsWith('.ps1','InvariantCultureIgnoreCase')){
                    # PowerShell setup file.  Handle arguments in the script wrapper
                    $UIControls.txt_InstallArgs.Text = ''
                    $UIControls.txt_InstallArgs.IsEnabled = $false
                    # Reset vars
                    $Script:AppName = ''
                    $Script:Publisher = ''
                    $Script:Version = ''
                    $Script:ProductCode = ''

                }else{
                    # Setup file is an EXE
                    Write-TxtLog "Getting EXE properties..."
                    $objInstaller = get-item -Path $Path
                    try{
                        $Script:AppName = Resolve-String -data $($objInstaller.VersionInfo.ProductName)
                        $Script:Publisher = Resolve-String -data $($objInstaller.VersionInfo.CompanyName)
                        $Script:Version = Resolve-String -data $($objInstaller.VersionInfo.ProductVersionRaw.ToString())
                        $Script:ProductCode = ''
                        Write-TxtLog "Success" -indent 1
                    }catch{
                        Write-TxtLog "Failed '$_'" -indent 1 -severity ERROR
                    }

                    $Script:InstallArgs = "/S" # default arg
                    $UIControls.txt_InstallArgs.Text = $Script:InstallArgs

                }
    
            }
        }#EndFunction

        Function Test-Auth{

            # Check token is still valid - in case there is a long pause between user actions
            Write-TxtLog "Testing authentication to tenant '$Script:TenantID' as application with id '$Script:ClientID'..."
            if ($null -eq $Global:AuthenticationHeader){
                Write-TxtLog "No existing token" -indent 1
                try{
                    Connect-MSIntuneGraph -TenantID $Script:TenantID -ClientID $Script:ClientID -interactive -ErrorAction stop | out-null
                }catch{
                    Write-TxtLog "Authentication failed '$_'. Unable to contiune" -indent 1 -severity ERROR
                    break
                }
            }else {
                # Make sure existing token is not expiring within 10 minutes
                $TokenLifeTime = ($Global:AuthenticationHeader.ExpiresOn - (Get-Date).ToUniversalTime()).TotalMinutes
                if ($TokenLifeTime -le 10){
                    Write-TxtLog "Token needs to be refreshed" -indent 1
                    Remove-variable -Name 'AuthenticationHeader' -Scope Global -Force -ErrorAction SilentlyContinue
                    try{
                        Connect-MSIntuneGraph -TenantID $Script:TenantID -ClientID $Script:ClientID -interactive | out-null
                    }catch{
                        Write-TxtLog "Authentication failed '$_'. Unable to contiune" -indent 1 -severity ERROR
                        break
                    }
                }else{
                    Write-TxtLog "Existing valid token" -indent 1
                }
            }

        }#EndFunction

        Function Format-DisplayName{

            # Only include architecture / language code in displayname if there are non-default
            if(($Script:Language -ne $Script:DefaultLanguage) -or ($Script:Architecture -ne $Script:DefaultArchitecture)){
                $Suffix = ''
                if($Script:Language -ne $Script:DefaultLanguage){
                    $Suffix += " $Script:LanguageCode"
                }

                if($Script:Architecture -ne $Script:DefaultArchitecture){
                    $Suffix += " $Script:Architecture"
                }

                $UIControls.txt_DisplayName.Text = [String]::Format("{0} {1} {2} P{3}{4}",$Script:Publisher,$Script:AppName,$Script:Version,$Script:PkgNum,$Suffix)
            }else{
                $UIControls.txt_DisplayName.Text = [String]::Format("{0} {1} {2} P{3}",$Script:Publisher,$Script:AppName,$Script:Version,$Script:PkgNum)
            }

        }

        Function Test-DisplayName{
            # Disable the next button and show a status bar warning if name matches an existing Win32 app
            if($Script:Win32Apps.ContainsKey($UIControls.txt_DisplayName.Text)){
                $UIControls.txt_Status.Text = "There is already a Win32 application with this name."
                $UIControls.txt_Status.Foreground = 'Red'
                Write-TxtLog "DisplayName : Name conflict for '$($UIControls.txt_DisplayName.Text)'"

            }else{
                $UIControls.txt_Status.Text = ''
                $UIControls.txt_Status.Foreground = 'Black'
                Write-TxtLog "DisplayName : No conflict for '$($UIControls.txt_DisplayName.Text)'"
            }
        }

        Function Reset-StatusBar{
            $UIControls.txt_Status.Text = ""
            $UIControls.txt_Status.Foreground = "Black"
         }

        #ENDREGION

        #REGION ----------Build UI---------
                
        $xmlMainWindow = LoadXml("$ScriptRoot\Xaml\MainWindow.xaml")
        $xmlPage1 = LoadXml("$ScriptRoot\Xaml\Page1.xaml")
        $xmlPage2 = LoadXml("$ScriptRoot\Xaml\Page2.xaml")
        $xmlPage3 = LoadXml("$ScriptRoot\Xaml\Page3.xaml")
        $xmlPage4 = LoadXml("$ScriptRoot\Xaml\Page4.xaml")

        $UIControls.MainWindow = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xmlMainWindow))
        $UIControls.Page1 = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xmlPage1))
        $UIControls.Page2 = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xmlPage2))
        $UIControls.Page3 = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xmlPage3))
        $UIControls.Page4 = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xmlPage4))

        # Create variables for each named element in MainWindow and each page
        $XmlMainWindow.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object -Process {
            $UIControls.$($_.Name) = $UIControls.MainWindow.FindName($_.Name)
        }

        $xmlPage1.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object -Process {
            $UIControls.$($_.Name) = $UIControls.Page1.FindName($_.Name)
        }

        $xmlPage2.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object -Process {
            $UIControls.$($_.Name) = $UIControls.Page2.FindName($_.Name)
        }

        $xmlPage3.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object -Process {
            $UIControls.$($_.Name) = $UIControls.Page3.FindName($_.Name)
        }

        $xmlPage4.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object -Process {
            $UIControls.$($_.Name) = $UIControls.Page4.FindName($_.Name)
        }

        # Set the startup page
        Write-TxtLog "Loading Page1"
        $UIControls.frame_Pages.Content = $UIControls.Page1
        $UIControls.txt_Banner.Text = "PACKAGE"
        $UIControls.MainWindow.WindowStartupLocation = [Windows.WindowStartupLocation]::CenterScreen

        # Broke these core parts of the script out for easier navigation and debugging
        Write-TxtLog "Loading Runspace functions and event handlers..."
        . $Script:ScriptRoot\Scripts\RunspaceFunctions.ps1
        . $Script:ScriptRoot\Scripts\EventHandlers.ps1

        #ENDREGION

         # Every 5 seconds, check for and clean-up any completed runspaces
        $UIControls.Timer = New-Object System.Windows.Forms.Timer
        $UIControls.Timer.Enabled = $true
        $UIControls.Timer.Interval = 5000
        $UIControls.Timer.Add_Tick({
            
            Foreach($job in $Global:BackgroundJobs){

                if($job.runspace.IsCompleted -eq $True){
                    Write-TxtLog "Runspace '$($job.powershell.runspace.name)' completed..."

                    # Save the additional streams to debug log
                    $Streams = @{
                        'Verbose'='VERBOSE'
                        'Warning'='WARN'
                        'Error'='ERROR'
                    }

                    Foreach($StreamType in $Streams.Keys){                        
                        $StreamOutput = $job.powershell.Streams."$StreamType"
                        if($StreamOutput){
                            Write-TxtLog "======================$StreamType output from runspace===================" -indent 1
                            $StreamOutput | Foreach-Object { Write-TxtLog $_ -indent 2 -severity $($Streams[$StreamType]) }
                            Write-TxtLog "======================End of $StreamType output==========================" -indent 1
                        }
                        Remove-Variable -name 'StreamOutput' -force -ErrorAction SilentlyContinue
                    }

                    Write-TxtLog "Disposing of runspace..." -indent 1
                    try{
                        $job.powerShell.EndInvoke($job.runspace)
                        $job.powerShell.runspace.Dispose()
                        
                        # Remove the job from the tracking list
                        try{
                            [System.Threading.Monitor]::Enter($Global:BackgroundJobs.SyncRoot)
                            $Global:BackgroundJobs.Remove($job)
                        }finally{
                            [System.Threading.Monitor]::Exit($Global:BackgroundJobs.SyncRoot)
                        }
                        
                        Write-TxtLog "Success" -indent 2

                    }catch{
                        Write-TxtLog "Failed '$_'" -indent 2 -severity ERROR
                    }
                }
            }#foreach

        })#sb_Timer

        $UIControls.Timer.Start()
        Write-TxtLog "Showing Main Form..."
        $UIControls.MainWindow.ShowDialog()        

    } #$sb_Main


    $ScriptName = $MyInvocation.MyCommand.Name
    $Script:LogFile = [string]::Format("{0}\{1}_{2}_Debug.log",$LogFolder,$ScriptName,$(Get-Date -Format 'yyyy-MM-dd_hhmmss'))
    $Script:WriteHost = $WriteHost
    Write-TxtLog "Starting script logged on as $($ENV:username)"
    
    # Making these variables global makes it easier to debug after the script has stopped
    $Global:BackgroundJobs = [system.collections.arraylist]::Synchronized((New-Object System.Collections.ArrayList))
    $global:UIControls=[hashtable]::Synchronized(@{})

    # Authenticate using MSAL.PS
    Write-TxtLog "Authenticating to tenant '$TenantID' as application with id '$ClientID'..."
    if ($null -eq $Global:AuthenticationHeader){
        Write-TxtLog "No existing token" -indent 1
        try{
            Connect-MSIntuneGraph -TenantID $TenantID -ClientID $ClientID -interactive -ErrorAction stop | out-null
        }catch{
            Write-TxtLog "Authentication failed '$_'. Unable to contiune" -indent 1 -severity ERROR
            break
        }
    }else {
        # Make sure existing token is not expiring within 10 minutes
        $TokenLifeTime = ($Global:AuthenticationHeader.ExpiresOn - (Get-Date).ToUniversalTime()).TotalMinutes
        if ($TokenLifeTime -le 10){
            Write-TxtLog "Token needs to be refreshed" -indent 1
            Remove-variable -Name 'AuthenticationHeader' -Scope Global -Force -ErrorAction SilentlyContinue
            try{
                Connect-MSIntuneGraph -TenantID $TenantID -ClientID $ClientID -interactive | out-null
            }catch{
                Write-TxtLog "Authentication failed '$_'. Unable to contiune" -indent 1 -severity ERROR
                break
            }
        }else{
            Write-TxtLog "Existing valid token" -indent 1
        }
    }

    # Check auth wasn't cancelled or failed
    if ($null -eq $Global:AuthenticationHeader){
        Write-TxtLog "Authentication failed. Stopping" -indent 1 -severity ERROR
        break
    }else{
        Write-TxtLog "Authentication completed" -Indent 1
    }
    
    # Display the form on a new runspace
    Write-TxtLog "Starting UI runspace..."
    $initialSessionState = [initialsessionstate]::CreateDefault()

    # Add modules to runspace
    $initialSessionState.ImportPSModule('IntuneWin32App')
    $initialSessionState.ImportPSModule('MSAL.PS')

    # Add functions to runspace
    $function = 'Write-TxtLog'
    $definition = Get-Content "Function:\$function"
    $entry = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $function, $definition
    $initialSessionState.Commands.Add($entry)

    $Runspace = [runspacefactory]::CreateRunspace($initialSessionState)

    $Runspace.ApartmentState = "STA"
    $Runspace.ThreadOptions = "ReuseThread"
    $Runspace.Name = "MainUI"
    $Runspace.Open()

    $Runspace.SessionStateProxy.SetVariable('BackgroundJobs',$Global:BackgroundJobs) # Tracks runspace jobs 
    $Runspace.SessionStateProxy.SetVariable('UIControls',$Global:UIControls) # User interface

    # Debug Logging variables
    $Runspace.SessionStateProxy.SetVariable('Logfile',$Script:Logfile)
    $Runspace.SessionStateProxy.SetVariable('WriteHost',$Script:WriteHost)

    # Variables created by IntuneWin32App Connect-MSIntuneGraph
    $Runspace.SessionStateProxy.SetVariable('AuthenticationHeader',$Global:AuthenticationHeader) 
    $Runspace.SessionStateProxy.SetVariable('AccessToken',$Global:AccessToken)
    $Runspace.SessionStateProxy.SetVariable('AccessTokenTenantID',$Global:AccessTokenTenantID)
    $Runspace.SessionStateProxy.SetVariable('ScriptRoot',$PSScriptRoot)
    $Runspace.SessionStateProxy.SetVariable('TenantID',$TenantID)
    $Runspace.SessionStateProxy.SetVariable('ClientID',$ClientID)

    $UIPowerShell = [powershell]::Create().AddScript($sb_Main,$True)

    # Register code to run when mainui is closed by the user
    $null = Register-ObjectEvent -InputObject $UIPowerShell -EventName InvocationStateChanged -Action {
        param([System.Management.Automation.PowerShell]$PS)
        $state = $EventArgs.InvocationStateInfo.State
        
        if ($state -in 'Completed', 'Failed') {

            # move inputline to end of console window
            [Console]::WriteLine() 
            [system.windows.forms.sendkeys]::SendWait("{Enter}")
            prompt

            $PS.Runspace.Dispose() # dispose of MainUI runspace

            # Dispose of any lingering additional runspaces
            Get-Runspace | Foreach-Object{
                if($_.id -ne 1){$_.Dispose()}
            }

            [GC]::Collect()
        }
    } #sb    

    $UIPowerShell.Runspace = $Runspace
    $null = $UIPowerShell.BeginInvoke()
}

