#REGION -------------RUNSPACE FUNCTIONS-------------

Function New-AppGroups{
    # Create Azure AD app groups using a new runspace

    $sb_AppGroups = {

        $Script:LogFile = $LogFile
        $Script:WriteHost = $WriteHost

        Write-TxtLog "Creating App Groups..."


        # Status bar
        $UIControls.txt_Status.Dispatcher.invoke([action]{
            $UIControls.txt_Status.Text="Creating App Groups..."
        },
        "Normal")

        # Wait cursor
        $UIControls.MainWindow.Dispatcher.Invoke([action]{
            $CurrentCursor = $UIControls.MainWindow.Cursor
            $UIControls.MainWindow.Cursor = [System.Windows.Input.Cursors]::Wait
        })

        # Required, Available, Uninstall groups
        Foreach($AppGroupType in $AppGroups.keys){
            Write-TxtLog "Processing $AppGroupType group '$($AppGroups[$AppGroupType])'..." -indent 1
        
            $Description = switch($AppGroupType){
                'Required'{
                    "Required install of $Publisher $AppName $Version"
                }
                'Available' {
                    "Available install of $Publisher $AppName $Version"
                }
                'Uninstall' {
                    "Uninstall of $Publisher $AppName $Version"
                }
            }

            Write-TxtLog "Description = '$Description' ; Owner = '$([string]::Join(';',$Owners))'" -indent 2

            # Check for existing group
            $Result = Get-IntuneWin32AppGroup -displayName $($AppGroups[$AppGroupType])
            if($null -eq $Result){
                Write-TxtLog "Does not already exist" -indent 2

                # Create the group using MS Graph
                $Result = Add-IntuneWin32AppGroup -DisplayName $($AppGroups[$AppGroupType]) -Description $Description -Owner $Owners

                if ($Result.'@odata.context' -like "*#groups*"){
                    $ID = $($Result.id)
                    Write-TxtLog "Created group with id '$($Result.id)'" -indent 3
                }else{
                    $ID = $null
                    Write-TxtLog "Failed to create - '$Result'" -indent 3 -severity ERROR
                }
            }else{
                $ID = $($Result.id)
                Write-TxtLog "Group already exists - id = $($Result.id)" -indent 2
            }

            if($ID){
                # Save the group IDs for use in assignment step
                [System.Threading.Monitor]::Enter($AssignmentGroups.syncroot)
                $AssignmentGroups[$AppGroupType] = $ID
                [System.Threading.Monitor]::Exit($AssignmentGroups.syncroot)
            }
        }

        # Cursor
        $UIControls.MainWindow.Dispatcher.Invoke([action]{
            $UIControls.MainWindow.Cursor = $CurrentCursor
        })

        # Status bar
        $UIControls.txt_Status.Dispatcher.invoke([action]{
            $UIControls.txt_Status.Text="Finished creating App Groups"
        },
        "Normal")

        # Enable Create Win32App button
        $UIControls.btn_CreateWin32App.Dispatcher.invoke([action]{
            $UIControls.btn_CreateWin32App.IsEnabled = $True
        },
        "Normal")
    }#sb

    # Groups to create and their descriptions
    $AppGroups=@{
        'Required' = "$($Script:GroupRequired)"
        'Available' = "$($Script:GroupAvailable)"
        'Uninstall' = "$($Script:GroupUninstall)"
    }
    
    $varsToImport = @{
        AuthenticationHeader=$Global:AuthenticationHeader
        UIControls=$Script:UIControls
        AppGroups=$AppGroups
        owners=$Script:Owners
        publisher = $Script:Publisher
        AppName = $Script:AppName
        Version = $Script:Version
        AssignmentGroups = $Script:AssignmentGroups
        LogFile=$Script:LogFile
        WriteHost=$Script:WriteHost
        VerbosePreference = 'Continue'
    }

    $UIControls.btn_CreateGroups.IsEnabled = $False # Avoid button mashing
    Test-Auth # Check token hasn't expired
    Write-TxtLog "Starting a new runspace 'CreateGroups'..."
    Invoke-Runspace -codeToRun $sb_AppGroups -varsToImport $varsToImport -modulesToLoad @('IntuneWin32App','MSAL.PS') -functionsToImport @('Add-IntuneWin32AppGroup','Get-IntuneWin32AppGroup','Write-TxtLog') -Name "CreateGroups"
}


Function New-IntuneWin{
    # Create Win32 App Package in the output folder

    $sb_IntuneWin={
        $Script:logFile = $logfile
        $Script:WriteHost = $WriteHost
        
        Write-TxtLog "Creating Win32 intunewin package..."
        Write-TxtLog "SourceFolder = $SourceFolder" -indent 1
        Write-TxtLog "SetupFile = $SetupFile" -indent 1
        Write-TxtLog "OutputFolder = $OutputFolder" -indent 1
        Write-TxtLog "PackageName=$PackageName" -indent 1

        # Status bar
        $UIControls.txt_Status.Dispatcher.invoke([action]{
            $UIControls.txt_Status.Text="Creating .intunewin package. Please wait..."
        },
        "Normal")

        # Wait cursor
        $UIControls.MainWindow.Dispatcher.Invoke([action]{
            $CurrentCursor = $UIControls.MainWindow.Cursor
            $UIControls.MainWindow.Cursor = [System.Windows.Input.Cursors]::Wait
        })

        try{
            $Win32AppPackage = New-IntuneWin32AppPackage -SourceFolder $SourceFolder -SetupFile $SetupFile -OutputFolder $OutputFolder -ErrorAction Stop -Verbose
            $Message = 'Package created successfully.'
            if($Win32AppPackage){
                Write-TxtLog "Created with initial name '$($Win32AppPackage.path)'" -indent 2

                if(Test-Path -path $OutputFolder\$PackageName){
                    Write-TxtLog "Deleting existing package '$OutputFolder\$PackageName'" -indent 2
                    try{
                        Remove-Item -path "$OutputFolder\$PackageName" -force -ErrorAction Stop
                        Write-TxtLog "Success" -indent 3
                    }catch{
                        Write-TxtLog "Failed - '$_'" -indent 3 -severity ERROR
                        $Message = 'Something went wrong. Check the debug log'
                    }
                }

                Write-TxtLog "Attempting to rename to '$PackageName'..." -indent 2
                try{
                    Rename-Item -Path "$($Win32AppPackage.Path)" -NewName $PackageName -ErrorAction Stop
                    Write-TxtLog "Success" -indent 3
                }catch{
                    Write-TxtLog "Failed '$_'" -indent 3 -severity ERROR
                }

                $script:Created_IntuneWinEncrypted = $True
            }else{
                Write-TxtLog "Failed to create .intunewin. Check the verbose/warning/error stream" -indent 2 -severity ERROR
                $Message = 'Something went wrong. Check the debug log'
            }
        }catch{
            Write-TxtLog "Unexpected error '$_'" -indent 2 -severity ERROR
            $Message = 'Something went wrong. Check the debug log'
        }

        # Cursor
        $UIControls.MainWindow.Dispatcher.Invoke([action]{
            $UIControls.MainWindow.Cursor = $CurrentCursor
        })
        
        # Status bar
        $UIControls.txt_Status.Dispatcher.invoke([action]{
            $UIControls.txt_Status.Text=$Message
        },
        "Normal")
        
        # Enable Create Assignment groups button
        $UIControls.btn_CreateWin32App.Dispatcher.invoke([action]{
            $UIControls.btn_CreateGroups.IsEnabled = $True
        },
        "Normal")

    }#sb

    $varsToImport = @{
        AuthenticationHeader=$Global:AuthenticationHeader
        UIControls=$Script:UIControls
        SourceFolder=$Script:SourceFolder
        SetupFile=$Script:SetupFile
        OutputFolder=$Script:Output_Folder
        PackageName=$Script:PackageName
        Logfile = $Script:LogFile
        WriteHost = $Script:WriteHost
        VerbosePreference = 'Continue'
    }


    $UIControls.btn_IntuneWin.IsEnabled = $False  # Prevent button mashing

    Write-TxtLog "Starting a new runspace 'CreatePackage'..."
    Invoke-Runspace -codeToRun $sb_IntuneWin -varsToImport $varsToImport -modulesToLoad @('IntuneWin32App','MSAL.PS') -functionsToImport @('Write-TxtLog') -Name 'CreatePackage'
}

Function Update-WrapperScripts{
    # Creates the install.ps1 and uninstall.ps1 scripts in the source folder
    # Uses templates in the \WrapperTemplates folder, replacing variables with required values

    $sb_WrapperUpdate = {

        $Script:LogFile = $Logfile
        $Script:Writehost = $WriteHost

        # Status bar
        $UIControls.txt_Status.Dispatcher.invoke([action]{
            $UIControls.txt_Status.Text="Creating wrapper scripts in source folder..."
        },
        "Normal")

        # Wait cursor
        $UIControls.MainWindow.Dispatcher.Invoke([action]{
            $CurrentCursor = $UIControls.MainWindow.Cursor
            $UIControls.MainWindow.Cursor = [System.Windows.Input.Cursors]::Wait
        })

        Write-TxtLog "Creating install / uninistall wrapper scripts from templates..."
        Write-TxtLog "script folder = '$ScriptFolder'; SourceFolder = '$SourceFolder'; SetupFile='$SetupFile'" -indent 1

        if($SetupFile.EndsWith('.msi','InvariantCultureIgnoreCase')){
            $SetupType = "MSI"
        }elseif($SetupFile.EndsWith('.ps1','InvariantCultureIgnoreCase')){
            $SetupType = "PS1"
        }else{
            $SetupType = "EXE"
        }

        Write-TxtLog "Setup type = '$SetupType'"
        
        Foreach($file in @("install.ps1","uninstall.ps1")){
            Write-TxtLog "Processing file '$File'"

            if($SetupType -eq 'MSI'){
                # Modify setupfile to use MSIEXEC instead of the .MSI file directly
                $Tokens['%SetupFile%'] = 'MSIEXEC.EXE'
                if($file -eq 'install.ps1'){
                    # Wrapper script automatically adds MSI logging so don't need to specify that
                    $Tokens['%SetupArgs%'] = "/i $SetupFile $($Tokens['%SetupArgs%'])"
                }
            }elseif($SetupType -eq 'PS1'){
                
                # Don't need to use Sysnative because this setup script will be called from 64-bit powershell installer
                $Tokens['%SetupFile%'] = '%Windir%\system32\windowspowershell\v1.0\powershell.exe'
                
                if($file -eq 'install.ps1'){
                    $Tokens['%SetupArgs%'] = "-noprofile -executionpolicy bypass -file $SetupFile"
                }else{
                    $Tokens['%SetupArgs%'] = "-noprofile -executionpolicy bypass -file $UninstallFile"
                }

            }

            # Remove existing wrapper script
            if(Test-Path -path "$SourceFolder\$file"){
                try{
                    Write-TxtLog "Attempting to delete existing '$file' in source folder" -indent 1
                    Remove-item -Path "$SourceFolder\$file" -Force -ErrorAction Stop
                    Write-TxtLog "Success" -indent 2
                }catch{
                    Write-TxtLog "Failed '$_'" -indent 2 -severity ERROR
                }
            }

            # Read template line by line and output with token replacement
            Write-TxtLog "Reading template '$file' in folder '$ScriptFolder\WrapperTemplates\$SetupType'..." -indent 1
            if(test-path -Path "$ScriptFolder\WrapperTemplates\$SetupType\$($file)"){

                Write-TxtLog "Writing updated '$file' to folder '$SourceFolder'" -indent 2
                Get-Content -Path "$ScriptFolder\WrapperTemplates\$SetupType\$($file)" -PipelineVariable 'pv' | ForEach-Object{
                    
                    Foreach($TokenKey in $Tokens.keys){
                        $PV = $PV.Replace($TokenKey,$Tokens[$TokenKey])
                    }
                    
                    $PV | Add-Content -Path "$SourceFolder\$file"
                }
                Write-TxtLog "Completed" -indent 2

            }else{
                Write-TxtLog "Template file was not found" -indent 2
            }
        }

        # Cursor
        $UIControls.MainWindow.Dispatcher.Invoke([action]{
            $UIControls.MainWindow.Cursor = $CurrentCursor
        })
        
        # Status bar
        $UIControls.txt_Status.Dispatcher.invoke([action]{
            $UIControls.txt_Status.Text="Wrapper scripts completed."
        },
        "Normal")
        
        # Enable Create package button
        $UIControls.btn_IntuneWin.Dispatcher.invoke([action]{
            $UIControls.btn_IntuneWin.IsEnabled = $True
        },
        "Normal")

    }#sb

    # Variables replaced in the .ps1 script wrapper templates
    # Template scripts have placeholders like %Packagename%
    $Tokens = @{
        '%DisplayName%' = $Script:DisplayName
        '%Publisher%' = $Script:Publisher
        '%AppName%' = $Script:AppName
        '%Version%' = $Script:Version
        '%PackageName%' = $Script:PackageName
        '%DetectionFilePath%' = $Script:DetectionFilePath
        '%SetupFile%' = $Script:SetupFile
        '%SetupArgs%' = $Script:InstallArgs
        '%UninstallFile%' = $Script:UninstallFile
        '%UninstallArgs%' = $Script:UninstallArgs
        '%ProductCode%' = $Script:ProductCode
        '%Date%' = $(Get-Date -format yyyy-MM-dd)
    }

    # Variables imported into the runspace
    $varsToImport = @{
        UIControls=$Script:UIControls
        sourcefolder=$Script:SourceFolder
        Tokens=$Tokens
        SetupFile=$Script:SetupFile
        UninstallFile=$Script:UninstallFile
        ScriptFolder=$Script:ScriptRoot
        LogFile = $Script:LogFile
        Writehost = $Script:WriteHost
        VerbosePreference = 'Continue'
    }

    $UIControls.btn_WrapperFiles.IsEnabled = $False # Prevent button mashing

    Write-TxtLog "Starting a new runspace 'CreateWrapper'..."
    Invoke-Runspace -codeToRun $sb_WrapperUpdate -varsToImport $varsToImport -functionsToImport @('Write-TxtLog') -Name 'CreateWrapper'
}

Function New-Win32App{
    # Create the Win32app in Intune and upload the .intunewin package
    # Dependency, Supercedence and Assignment are not in this step. They happen later

    $sb_NewWin32App = {

        $Global:AuthenticationHeader = $AuthenticationHeader
        $Global:AccessToken = $AccessToken
        $Global:AccessTokenTenantID = $AccessTokenTenantID
        $Script:logFile = $Logfile
        $Script:WriteHost=$WriteHost

        # Status bar
        $UIControls.txt_Status.Dispatcher.invoke([action]{
            $UIControls.txt_Status.Text='Creating Win32App in Intune...'
        },
        "Normal")

        # Wait cursor
        $UIControls.MainWindow.Dispatcher.Invoke([action]{
            $CurrentCursor = $UIControls.MainWindow.Cursor
            $UIControls.MainWindow.Cursor = [System.Windows.Input.Cursors]::Wait
        })

        Write-TxtLog "Creating requirement rule JSON fragment"
        $RequirementRule = New-IntuneWin32AppRequirementRule -Architecture $AppProperties.RequirementArch -MinimumSupportedWindowsRelease $AppProperties.RequirementVersion
        Write-TxtLog "Completed" -indent 1

        # Create detection rule
        Write-TxtLog "Creating file exists detection rule JSON fragment - folder: '$(Split-Path -Path $AppProperties.DetectionFile -Parent)';  file: '$(Split-Path -Path $AppProperties.DetectionFile -Leaf)' "
        $DetectionRule = New-IntuneWin32AppDetectionRuleFile -Path $(Split-Path -Path $AppProperties.DetectionFile -Parent) -FileOrFolder $(Split-Path -Path $AppProperties.DetectionFile -Leaf) -Existence -DetectionType exists
        Write-TxtLog "Completed" -indent 1

        # Add new MSI Win32 app
        $AppSplat = @{
            FilePath=$AppProperties.IntuneWinFile
            DisplayName=$AppProperties.DisplayName
            AppVersion=$AppProperties.Version
            Description=$AppProperties.Description
            Publisher=$AppProperties.Publisher
            InstallExperience=$AppProperties.Install
            RestartBehavior=$AppProperties.Restart
            DetectionRule=$DetectionRule
            RequirementRule=$RequirementRule
            InstallCommandLine=$AppProperties.InstallCommandLine
            UninstallCommandLine=$AppProperties.UninstallCommandLine
            Owner = $AppProperties.Owner
            verbose=$True
        }

        if($null -ne $AppProperties.Logo){
            Write-TxtLog "Encoding icon for '$($AppProperties.Logo)'"
            $Icon = New-IntuneWin32AppIcon -FilePath $AppProperties.Logo
            $AppSplat.Add('Icon',$Icon)
            Write-TxtLog "Completed" -indent 1
        }

        Write-TxtLog "Calling Add-IntuneWin32app..."
        Write-TxtLog "Parameters" -indent 1
        Foreach($k in $AppSplat.keys){
            if($k -eq 'Icon'){
                # Don't log the whole encoded file, just the path
                Write-TxtLog "Icon = '$($AppProperties.Logo)'" -indent 2
            }else{
                Write-TxtLog "$k = '$($AppSplat[$k])'" -indent 2
            }
        }

        # Status bar
        $UIControls.txt_Status.Dispatcher.invoke([action]{
            $UIControls.txt_Status.Text="Creating Win32App - may take some time.."
        },
        "Normal")
        
        $Result = Add-IntuneWin32App @AppSplat

        if($Result.'@odata.type' -eq '#microsoft.graph.win32LobApp'){
            #Write-TxtLog "Result.id = '$($Result.id)'"
            $UIMessage ='App created successfully'

            [System.Threading.Monitor]::Enter($Win32AppID.syncroot)
            $Win32AppID.Add('AppGroupID',$Result.id)
            [System.Threading.Monitor]::Exit($Win32AppID.syncroot)

            Write-TxtLog "Completed successfully" -indent 1

        }else{
            $UIMessage ='Something went wrong. Check the debug log'
            Write-TxtLog "Something went wrong" -indent 1 -severity ERROR
        }

        # Cursor
        $UIControls.MainWindow.Dispatcher.Invoke([action]{
            $UIControls.MainWindow.Cursor = $CurrentCursor
        })

        # Update status bar
        $UIControls.txt_Status.Dispatcher.invoke([action]{
            $UIControls.txt_Status.Text=$UIMessage
        },
        "Normal")

        # Enable UI buttons depending on dependency and superdedence settings
        If($SelectedDependecy -ne 'None' -and ($null -ne $SelectedDependecy)){

            $UIControls.btn_Dependency.Dispatcher.Invoke([action]{
                $UIControls.btn_Dependency.IsEnabled=$True
            },"Normal")
        
        }elseif($SelectedSupercedence -ne 'None' -and ($null -ne $SelectedSupercedence)){

            $UIControls.btn_Supercedence.Dispatcher.Invoke([action]{
                $UIControls.btn_Supercedence.IsEnabled=$True
            },"Normal")

        }else{

            $UIControls.btn_Assignment.Dispatcher.Invoke([action]{
                $UIControls.btn_Assignment.IsEnabled=$True
            },"Normal")

        }          

    }#sb

    $AppProperties = @{
        IntuneWinFile = "$($Script:Output_Folder)\$($Script:PackageName)"
        DisplayName = $Script:DisplayName
        Publisher = $Script:Publisher
        Description = $Script:Description
        Install = 'System'
        Restart = 'Suppress'
        DetectionFile = $Script:DetectionFilePath
        RequirementArch = $Script:Architecture
        RequirementVersion = $Script:MinimumOS
        Logo = $Script:LogoFile
        InstallCommandLine=$Script:Win32InstallCmd
        UninstallCommandLine=$Script:Win32UninstallCmd
        Version = $Script:Version
        PkgNum = $Script:PkgNum
        Owner = ([string]::Join(';',$Script:Owners)).Trim(';')
    }

    $varsToImport = @{
        AuthenticationHeader=$Global:AuthenticationHeader
        AccessToken = $Global:AccessToken
        AccessTokenTenantID=$Global:AccessTokenTenantID
        UIControls=$Script:UIControls
        AppProperties = $AppProperties
        Win32AppID = $Script:Win32AppID
        SelectedDependecy = $UIControls.combo_Dependency.SelectedItem
        SelectedSupercedence = $UIControls.combo_Supercedence.SelectedItem
        Logfile=$Script:logFile
        Writehost=$Script:WriteHost
        VerbosePreference = 'Continue'
    }

    $UIControls.btn_CreateWin32App.IsEnabled = $False # Avoid button mashing

    Test-Auth # Check token hasn't expired

    Write-TxtLog "Starting a new runspace 'NewWin32App'..."
    Invoke-Runspace -codeToRun $sb_NewWin32App -varsToImport $varsToImport -modulesToLoad @('IntuneWin32App','MSAL.PS') -functionsToImport @('Write-TxtLog') -name 'NewWin32App'
}

Function Get-Win32Apps{
    # Get existing Win32 Apps to populate UI Dependency and Supercedence drop-downs

    $sb_GetAppsCode = {

        try{
            $Global:AuthenticationHeader = $AuthenticationHeader
            $Script:logFile = $Logfile
            $Script:WriteHost=$WriteHost

            Write-TxtLog "Getting Win32Apps from Intune..."
            try{
                # Not using the Get-IntuneWin32App function in IntuneWin32App module because it makes multiple API calls to get app info that isn't needed in this instance
                $Apps = Get-IntuneWin32AppEx | Select-Object id, displayName
                Write-TxtLog "Found '$($Apps.count)' apps" -indent 1
                Write-TxtLog "Populating dependency and supercedence lists" -indent 1
            }catch{
                Write-TxtLog "Failed '$_'" -indent 1 -severity ERROR
            }
            
            # Update combo boxes
            $UIControls.combo_Dependency.Dispatcher.invoke([action]{
                $Win32Apps.Clear()
                
                $UIControls.combo_Dependency.Items.Clear()
                $UIControls.combo_Dependency.Items.Add("None") | Out-Null
                $UIControls.combo_Dependency.SelectedItem="None"

                Foreach($app in $Apps){
                    # Update the UI
                    $UIControls.combo_Dependency.Items.Add($app.DisplayName) | Out-Null

                    # Store in shared variable
                    $Win32Apps.Add($app.DisplayName, $app.id) | Out-Null
                }
            },
            "Normal")

            $UIControls.combo_Supercedence.Dispatcher.invoke([action]{
                
                $UIControls.combo_Supercedence.Items.Clear()
                $UIControls.combo_Supercedence.Items.Add("None") | Out-Null
                $UIControls.combo_Supercedence.SelectedItem="None"

                Foreach($app in $Apps){
                    # Update the UI
                    $UIControls.combo_Supercedence.Items.Add($app.DisplayName) | Out-Null

                }
            },
            "Normal")
        }catch{
            Write-TxtLog "Unexpected error '$_'" -indent 1 -severity ERROR
        }
    }#sb

    $varsToImport = @{
        AuthenticationHeader=$Global:AuthenticationHeader
        UIControls=$Script:UIControls
        Win32Apps=$Script:Win32Apps
        Logfile=$Script:logFile
        Writehost=$Script:WriteHost
        VerbosePreference = 'Continue'
    }

    #Test-Auth # Check token hasn't expired

    Write-TxtLog "Starting a new runspace 'GetWin32Apps'..."
    Invoke-Runspace -codeToRun $sb_GetAppsCode -varsToImport $varsToImport -modulesToLoad @('IntuneWin32App','MSAL.PS') -functionsToImport('Write-TxtLog','Get-IntuneWin32AppEx') -Name 'GetWin32Apps'
              
}

Function Set-AssignmentGroups{
    # Adds a required, available and uninstall group to an application
    $sb_AssignGroupsCode = {

        # Status bar
        $UIControls.txt_Status.Dispatcher.invoke([action]{
            $UIControls.txt_Status.Text='Assigning app to groups...'
        },
        "Normal")

        # Wait cursor
        $UIControls.MainWindow.Dispatcher.Invoke([action]{
            $CurrentCursor = $UIControls.MainWindow.Cursor
            $UIControls.MainWindow.Cursor = [System.Windows.Input.Cursors]::Wait
        })

        Foreach($GroupType in $AssignmentGroups.Keys){
            Write-TxtLog "Adding assignment for $GroupType group '$($AssignmentGroups[$GroupType])' for new app with ID '$AppID'..." -indent 1

            switch($GroupType){
                'Required' {
                    $Result = Add-IntuneWin32AppAssignmentGroupEx -ID $AppID -GroupID $AssignmentGroups.Required -Include -Notification showAll -DeliveryOptimizationPriority foreground -Intent required -Verbose
                    #Add-IntuneWin32AppAssignmentGroupEx
                    if($Result.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget'){
                        Write-TxtLog "Success" -indent 2
                    }else{
                        Write-TxtLog "Failed. Check warning and error streams" -indent 2 -severity ERROR
                    }
                }
                'Available' {
                    $Result = Add-IntuneWin32AppAssignmentGroupEx -ID $AppID -GroupID $AssignmentGroups.Available -Include -Notification showAll -DeliveryOptimizationPriority foreground -Intent available -Verbose
                    if($Result.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget'){
                        Write-TxtLog "Success" -indent 2
                    }else{
                        Write-TxtLog "Failed. Check warning and error streams" -indent 2 -severity ERROR
                    }
                }

                'Uninstall' {
                    $Result = Add-IntuneWin32AppAssignmentGroupEx -ID $AppID -GroupID $AssignmentGroups.Uninstall -Include -Notification showAll -DeliveryOptimizationPriority foreground -Intent uninstall -Verbose
                    if($Result.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget'){
                        Write-TxtLog "Success" -indent 2
                    }else{
                        Write-TxtLog "Failed. Check warning and error streams" -indent 2 -severity ERROR
                    }

                    Write-TxtLog "Adding required exclusion for uninstall group..." -indent 1
                    $Result = Add-IntuneWin32AppAssignmentGroupEx -ID $AppID -GroupID $AssignmentGroups.Uninstall -Exclude -Intent required -Verbose

                    if($Result.target.'@odata.type' -eq '#microsoft.graph.exclusionGroupAssignmentTarget'){
                        Write-TxtLog "Success" -indent 2
                    }else{
                        Write-TxtLog "Failed. Check warning and error streams" -indent 2 -severity ERROR
                        Write-TxtLog "Likely to fail until this issue is fixed 'https://github.com/MSEndpointMgr/IntuneWin32App/issues/76'" -indent 2 -severity ERROR
                    }

                }
            }

            Remove-Variable -Name "Result" -Force -ErrorAction SilentlyContinue 
        }

        # Cursor
        $UIControls.MainWindow.Dispatcher.Invoke([action]{
            $UIControls.MainWindow.Cursor = $CurrentCursor
        })

        # Status bar
        $UIControls.txt_Status.Dispatcher.invoke([action]{
            $UIControls.txt_Status.Text="All tasks complete. Close the app and restart."
        },
        "Normal")

        Write-TxtLog "Finished assignment" -indent 1
    }#sb

    $varsToImport = @{
        AuthenticationHeader=$Global:AuthenticationHeader
        UIControls=$Script:UIControls
        AssignmentGroups=$Script:AssignmentGroups
        AppID = $Script:Win32AppID['AppGroupID']
        Logfile=$Script:logFile
        Writehost=$Script:WriteHost
        VerbosePreference = 'Continue'
    }

    $UIControls.btn_Assignment.IsEnabled = $False # Avoid button mashing

    Test-Auth # Check token hasn't expired

    Write-TxtLog "Starting a new runspace 'AssignGroups'..."
    Invoke-Runspace -codeToRun $sb_AssignGroupsCode -varsToImport $varsToImport -modulesToLoad @('IntuneWin32App','MSAL.PS') -functionsToImport('Write-TxtLog','Add-IntuneWin32AppAssignmentGroupEx') -Name 'AssignGroups'
}

Function Add-Dependency{

    $sb_Dependency = {

        # Status bar
        $UIControls.txt_Status.Dispatcher.invoke([action]{
            $UIControls.txt_Status.Text='Adding dependency to Intune app...'
        },
        "Normal")

        # Wait cursor
        $UIControls.MainWindow.Dispatcher.Invoke([action]{
            $CurrentCursor = $UIControls.MainWindow.Cursor
            $UIControls.MainWindow.Cursor = [System.Windows.Input.Cursors]::Wait
        })

        Write-TxtLog "Making App '$AppID' dependent on app '$Dependency' (auto-install)..."
        $Dep = New-IntuneWin32AppDependency -ID $Dependency -DependencyType AutoInstall

        Add-IntuneWin32AppDependency -ID $AppID -Dependency $Dep -Verbose
        Write-TxtLog "Completed. Check warning or error stream for confirmation" -indent 1

        # Cursor
        $UIControls.MainWindow.Dispatcher.Invoke([action]{
            $UIControls.MainWindow.Cursor = $CurrentCursor
        })
        
        # Status bar
        $UIControls.txt_Status.Dispatcher.invoke([action]{
            $UIControls.txt_Status.Text="Dependency completed."
        },
        "Normal")

        # Enable Assingment button
        $UIControls.btn_Assignment.Dispatcher.invoke([action]{
            $UIControls.btn_Assignment.IsEnabled=$True
        },
        "Normal")

    }#sb

    $varsToImport = @{
        AuthenticationHeader=$Global:AuthenticationHeader
        UIControls=$Script:UIControls
        Dependency = $Script:Dependency
        AppID = $Script:Win32AppID['AppGroupID']
        Logfile=$Script:logFile
        Writehost=$Script:WriteHost
        VerbosePreference = 'Continue'
    }

    $UIControls.btn_Dependency.IsEnabled = $False # Avoid button mashing

    Test-Auth # Check token hasn't expired

    Write-TxtLog "Starting a new runspace 'AddDependency'..."
    Invoke-Runspace -codeToRun $sb_Dependency -varsToImport $varsToImport -modulesToLoad @('IntuneWin32App','MSAL.PS') -functionsToImport('Write-TxtLog') -Name 'AddDependency'

}

Function Add-Supercedence{

    $sb_Supercedence = {

        # Status bar
        $UIControls.txt_Status.Dispatcher.invoke([action]{
            $UIControls.txt_Status.Text='Adding supercendence to Intune app...'
        },
        "Normal")

        # Wait cursor
        $UIControls.MainWindow.Dispatcher.Invoke([action]{
            $CurrentCursor = $UIControls.MainWindow.Cursor
            $UIControls.MainWindow.Cursor = [System.Windows.Input.Cursors]::Wait
        })

        Write-TxtLog "Making App '$AppID' supercede app '$Supercedence' (update)..."

        $Sup = New-IntuneWin32AppSupersedence -ID $Supercedence -SupersedenceType Update

        Add-IntuneWin32AppSupersedence -ID $AppID -Supersedence $sup -Verbose
        Write-TxtLog "Completed. Check warning or error stream for confirmation" -indent 1

        # Cursor
        $UIControls.MainWindow.Dispatcher.Invoke([action]{
            $UIControls.MainWindow.Cursor = $CurrentCursor
        })
        
        # Status bar
        $UIControls.txt_Status.Dispatcher.invoke([action]{
            $UIControls.txt_Status.Text="Supercedence completed."
        },
        "Normal")

        # Enable Assingment button
        $UIControls.btn_Assignment.Dispatcher.invoke([action]{
            $UIControls.btn_Assignment.IsEnabled=$True
        },
        "Normal")

    }#sb

    $varsToImport = @{
        AuthenticationHeader=$Global:AuthenticationHeader
        UIControls=$Script:UIControls
        Supercedence = $Script:Supercedence
        AppID = $Script:Win32AppID['AppGroupID']
        Logfile=$Script:logFile
        Writehost=$Script:WriteHost
        VerbosePreference = 'Continue'
    }

    $UIControls.btn.IsEnabled = $False # Avoid button mashing

    Test-Auth # Check token hasn't expired

    Write-TxtLog "Starting a new runspace 'AddSupercedence'..."
    Invoke-Runspace -codeToRun $sb_Supercedence -varsToImport $varsToImport -modulesToLoad @('IntuneWin32App','MSAL.PS') -functionsToImport('Write-TxtLog') -Name 'AddSupercedence'

}

Function Find-Owner{
    # Lookup users in AAD with UPN starting with the specified characters in txt_Owner
    # Add to the owner lookup list so user can select from the list
    $sb_Owner = {

        Write-TxtLog "Looking-up users with UPN starting '$Lookup'"
        $OwnerResult = Find-AADUser -ANR $Lookup -verbose
         
        if($OwnerResult.Count -gt 0){
            Write-TxtLog "Found $($OwnerResult.Count) users" -indent 1
            $UIControls.txt_Status.Dispatcher.invoke([action]{
                $UIControls.list_OwnerLookup.items.clear()
                foreach($o in $OwnerResult){                            
                    $UIControls.list_OwnerLookup.items.add($o.userprincipalName)
                }                    
            },"Normal")
        }else{
            Write-TxtLog "No users found" -indent 1
        }      
    }#sb

    $varsToImport = @{
        AuthenticationHeader=$Global:AuthenticationHeader
        UIControls=$Script:UIControls
        Lookup = $UIControls.txt_Owner.Text.Trim()
        Logfile=$Script:logFile
        Writehost=$Script:WriteHost
        VerbosePreference = 'Continue'
    }

    Test-Auth # Check token hasn't expired

    Write-TxtLog "Starting a new runspace 'FindOwner'..."
    Invoke-Runspace -codeToRun $sb_Owner -varsToImport $varsToImport -modulesToLoad @('IntuneWin32App','MSAL.PS') -functionsToImport('Write-TxtLog','Find-AADUser') -Name 'FindOwner'
 }

Function Invoke-Runspace{
    # Excutes a script block in a new runspace
    [cmdletbinding()]
    param(
     [ScriptBlock]$codeToRun
     ,
     [hashtable]$varsToImport
     ,
     [string[]]$modulesToLoad
     ,
     [string[]]$functionsToImport
     ,
     [string]$Name=[GUID]::NewGuid().ToString()
    )
    PROCESS{

        $initialSessionState = [initialsessionstate]::CreateDefault()
        foreach($module in $modulesToLoad){
            $initialSessionState.ImportPSModule($module)
        }

        foreach($function in $functionsToImport){
            $definition = Get-Content "Function:\$Function"
            $entry = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $function, $definition
            $initialSessionState.Commands.Add($entry)
        }

        $Runspace = [runspacefactory]::CreateRunspace($initialSessionState)
        $Runspace.ApartmentState = "STA"
        $Runspace.ThreadOptions = "ReuseThread"
        $Runspace.Name = $Name
        $Runspace.Open()
        
        $PS = [powershell]::Create().AddScript($codeToRun)

        Foreach($var in $varsToImport.keys){
            $Runspace.SessionStateProxy.SetVariable($var,$varsToImport[$var])                
        }
    
        $PS.Runspace = $Runspace
        $handle = $PS.BeginInvoke()

        $Global:BackgroundJobs.Add([PSCustomObject]@{
            powerShell = $PS
            runspace = $handle
        }) | Out-Null

    }
}

#ENDREGION
