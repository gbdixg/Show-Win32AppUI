
#REGION ----------EventHandlers----------

$UIControls.MainWindow.Add_Loaded({

    # Load data for language combo box
    Write-TxtLog "Loading language options..."
    try{
        $Script:LangCodes = import-csv -path "$($Script:ScriptRoot)\Lang.csv" -ErrorAction Stop
        Write-TxtLog "Loaded $($Script:LangCodes.Count) languages" -indent 1
    }catch{
        Write-TxtLog "Error '$_'" -indent 1 -severity ERROR
    }

    $Script:LanguageCode = $Script:LangCodes | Where-Object{$_.DiplayName -eq $Script:Language} | Select-Object -ExpandProperty Code
    
    # Populate lnaguage combo box
    Foreach($Lang in $Script:LangCodes){
        $UIControls.combo_language.Items.Add($Lang.DisplayName) | out-null
    }
                
    # Architecture combo box
    $UIControls.combo_Architecture.Items.Add("x64") | Out-Null
    $UIControls.combo_Architecture.Items.Add("x86") | Out-Null     

    $UIControls.Btn_Next.IsEnabled=$false
    $UIControls.Btn_Previous.IsEnabled=$false

    # Start getting existing Intune Win32 apps on another thread
    # Used to populate the dependency and supercedence combo boxes
    Get-Win32Apps

})

$UIControls.btn_Close.Add_Click({
    Write-TxtLog "Clicked button 'Close'"
    $UIControls.MainWindow.Close()
    break
})

$UIControls.Btn_Next.Add_Click({
# Move to next page
    Write-TxtLog "Clicked button 'Next'"
    switch($PageCounter){
        1 {
            # Move to page 2

            # Reset the navigation buttons
            $UIControls.Btn_Previous.IsEnabled=$true

            # Populate controls on next page
            $UIControls.combo_language.SelectedItem=$Script:Language
            $UIControls.combo_Architecture.SelectedItem=$script:Architecture 
            $UIControls.txt_PkgNum.Text = $Script:PkgNum # Package number defaults to 1

            $UIControls.txt_AppName.Text = $Script:AppName
            $UIControls.txt_PubName.Text = $Script:Publisher
            $UIControls.txt_Version.Text = $Script:Version
                
            # Set script level vars based on Page 1 UI entries
            $Script:UninstallFile = $UIControls.txt_UninstallFile.Text.Trim()
            $Script:UninstallArgs = $UIControls.txt_UninstallArgs.Text.Trim()

            Test-Page2 # Disable navigation buttons on next page until required fields are completed

            # Build application displayname
            Format-DisplayName

            # Set Page title
            $UIControls.txt_Banner.Text = "DEPLOYMENT"
            
            Reset-StatusBar

            Write-TxtLog "Showing Page2"
            $Script:PageCounter++
            $UIControls.frame_Pages.Content=$UIControls.Page2
            Test-DisplayName # show status bar warning if app already exists
            break
        }
        2{
            # Move to page 3
           
            # Populate controls on next page
            if($Script:AppName -ne ''){
                $UIControls.txt_RequiredGroup.Text = "$($Script:GroupPrefix)-I-$($Script:AppName)"
                $Script:GroupRequired = $UIControls.txt_RequiredGroup.Text

                $UIControls.txt_AvailableGroup.Text = "$($Script:GroupPrefix)-P-$($Script:AppName)"
                $Script:GroupAvailable = $UIControls.txt_AvailableGroup.Text

                $UIControls.txt_UninstallGroup.Text = "$($Script:GroupPrefix)-R-$($Script:AppName)"
                $Script:GroupUninstall = $UIControls.txt_UninstallGroup.Text
            }

            $UIControls.btn_Owner.IsEnabled=$False

            # Reset owner
            $UIControls.txt_Owner.Text=''

            # Set script level vars based on UI entries
            $Script:DisplayName = $UIControls.txt_DisplayName.Text.Trim()

            # Set page title
            $UIControls.txt_Banner.Text='ASSIGNMENT'

            Reset-StatusBar

            # Reset the navigation buttons
            $UIControls.Btn_Previous.IsEnabled=$true
            Test-Page3

            Write-TxtLog "Showing Page3"
            $Script:PageCounter++
            $UIControls.frame_Pages.Content=$UIControls.Page3
            break
        }

        3{
            # Move to page 4

            # Populate controls on next page
            $UIControls.btn_WrapperFiles.IsEnabled = $True
            $UIControls.btn_IntuneWin.IsEnabled = $False
            $UIControls.btn_CreateGroups.IsEnabled = $False
            $UIControls.btn_CreateWin32App.IsEnabled = $False
            $UIControls.btn_Assignment.IsEnabled = $False
            $UIControls.btn_Supercedence.IsEnabled = $False
            $UIControls.btn_Dependency.IsEnabled = $False

            # Set script level vars based on UI entries
            $Script:PackageName = ([String]::Format("{0}_{1}_{2}_{3}_{4}_P{5}.intunewin",$Script:Publisher,$Script:AppName,$Script:Version,$Script:Architecture,$Script:LanguageCode,$Script:PkgNum)).Replace(' ','_')
            $Script:DetectionFilePath = ([String]::Format("%ProgramData%\InstalledWin32Apps\{0}",$Script:PackageName)).Replace('.intunewin','.ps1.tag').Replace(' ','_')
            #$Script:Owners = [Array]$UIControls.list_OwnerAdded.Items
            
            # Set page title
            $UIControls.txt_Banner.Text='IMPLEMENT'

            Reset-StatusBar

            # Reset the navigation buttons
            $UIControls.Btn_Previous.IsEnabled=$true
            $UIControls.Btn_Next.IsEnabled=$false
            
            Write-TxtLog "Showing Page4"
            $Script:PageCounter++
            $UIControls.frame_Pages.Content=$UIControls.Page4
            break
        }

        default{
            break
        }
    }
})

$UIControls.Btn_Previous.Add_Click({
    # Move to previous page
    Write-TxtLog "Clicked button 'Previous'"
    switch($PageCounter){
        2 {
            # Move to page 1

            # Reset the navigation buttons
            $UIControls.Btn_Previous.IsEnabled=$false
            Test-Page1 # only enable next if required fields completed

            # Set the page title
            $UIControls.txt_Banner.Text="PACKAGE"

            Reset-StatusBar

            Write-TxtLog "Showing Page1"
            $Script:PageCounter--
            $UIControls.frame_Pages.Content=$UIControls.Page1
            break
        }
        3{
            # Move to page 2

            # Reset the navigation buttons
            $UIControls.Btn_Previous.IsEnabled=$true
            Test-Pag2 # only enable next if required fields completed

            # Set the page title
            $UIControls.txt_Banner.Text="DEPLOYMENT"

            Reset-StatusBar

            Write-TxtLog "Showing Page2"
            $Script:PageCounter--
            $UIControls.frame_Pages.Content=$UIControls.Page2
            break
        }

        4{
            # Move to page 3
            $UIControls.txt_Owner.Text=''
            $UIControls.Btn_Previous.IsEnabled=$true
            Test-Page3 # only enable next if required fields completed

            $UIControls.txt_Owner.Text=''

             # Set the page title
            $UIControls.txt_Banner.Text="ASSIGNMENT"

            Reset-StatusBar

            Write-TxtLog "Showing Page3"
            $Script:PageCounter--
            $UIControls.frame_Pages.Content=$UIControls.Page3
            break
        }

        default{
            break
        }
    }
})

$UIControls.btn_SetupFile.Add_Click({
    # Show a dialog to select the setupfile

    Write-TxtLog "Clicked button 'SetupFile'"

    $File = Select-File -InitialDirectory $Script:initialDirectory -Filter "Setup Files|*.msi;*.exe;*.ps1|All Files|*.*"
    if($file){
        Write-TxtLog "Selected install file '$file'"

        # Only show the file name in the UI but record the full path
        $UIControls.txt_SetupFile.Text = $(Split-Path -Path $File -Leaf)
        $Script:SetupFile = $UIControls.txt_SetupFile.Text.Trim()

        # Setup file parent folder will be the source folder for the package
        $UIControls.txt_Source.Text = $(Split-Path -path $File -Parent)
        $Script:SourceFolder = $UIControls.txt_Source.Text.Trim()

        $InstallFiles = get-childitem -path $Script:SourceFolder -force -ErrorAction SilentlyContinue | ?{$_.Name -match '^install.ps1$|^uninstall.ps1$'}
        if($InstallFiles){
            $UIControls.txt_Status.Text = "Warning: Existing install.ps1 or uninstall.ps1 in source folder"
            $UIControls.txt_Status.Foreground = 'Red'
        }
        
        # Get MSI or EXE properties for default Appname / Publisher / Version
        # These are initial properties that can be edited
        Get-SetupInfo -path "$($Script:SourceFolder)\$($Script:SetupFile)"

        if($file.EndsWith('.msi','InvariantCultureIgnoreCase')){
            # MSI will use MSIEXEC /x {productcode} to uninstall
            $UIControls.btn_UninstallFile.IsEnabled = $False
            $UIControls.btn_UninstallFile.Visibility = 'Hidden'
            $UIControls.txt_UninstallFile.Text = "MSIEXEC.EXE"
            $UIControls.txt_UninstallArgs.Text = "/x $($Script:ProductCode) /q"
            $Script:UninstallFile = $UIControls.txt_UninstallFile.Text

        }else{
            $UIControls.btn_UninstallFile.IsEnabled = $True
            $UIControls.btn_UninstallFile.Visibility = 'Visible'
            $UIControls.txt_UninstallFile.Text = ''
            $UIControls.txt_UninstallArgs.Text = ''
        }
                        
    }

    Test-Page1 # Are all required fields complete on this page?
}) 

$UIControls.btn_UninstallFile.Add_Click({
    # Show a dialog to select the uninstall file
    # Operator can also enter the path manually

    Write-TxtLog "Clicked button 'UninstallFile'"

    $File = Select-File -InitialDirectory $Script:initialDirectory -Filter "Setup Files|*.msi;*.exe;*.ps1|All Files|*.*"
    if($File){
        Write-TxtLog "Selected uninstall file '$File'"
        
        $Script:UninstallFile = $File
        $UIControls.txt_UninstallFile.Text = $File
        
        if($UIControls.txt_UninstallFile.Text.EndsWith('.ps1','InvariantCultureIgnoreCase')){
            # PowerShell uninstall script. Handle arguments in the script wrapper
            $UIControls.txt_UninstallArgs.Text = ''
            $UIControls.txt_UninstallArgs.IsEnabled = $False
        }


    }
    Test-Page1 # Are all required fields complete on this page?
})

$UIControls.txt_UninstallFile.Add_TextChanged({
    $Script:UninstallFile = $UIControls.txt_uninstall.Text

    if($UIControls.txt_UninstallFile.Text.EndsWith('.ps1','InvariantCultureIgnoreCase')){
       
        # PowerShell uninstall script. Handle arguments in the script wrapper
        $UIControls.txt_UninstallArgs.Text = ''
        $UIControls.txt_UninstallArgs.IsEnabled = $False
    }

    Test-Page1 # Are all required fields complete on this page?
})

$UIControls.btn_LogoFile.Add_Click({
    # Show a dialog to select the app logo
    Write-TxtLog "Clicked button 'Logo'"

    $File = Select-File -InitialDirectory $Script:initialDirectory -Filter "Image Files|*.png;*.jpg;*.jpeg;*.bmp|All Files|*.*"
    "txt files (*.txt)|*.txt|All files (*.*)|*.*"
    if($file){

        # Update the UI
        $UIControls.btn_LogoImage.Source=$file

        $Script:LogoFile = $File
        Write-TxtLog "Selected logo file $($Script:LogoFile)"
    }
    Test-Page3 # Are all required fields complete on this page?
})

$UIControls.btn_Output.Add_Click({
    # Show a dialog to select the output folder, where the .intunewin will be created
    Write-TxtLog "Clicked button 'OutputFolder'"

    $Folder = Select-Folder -InitialDirectory $Script:initialDirectory
    if($Folder -eq $Script:SourceFolder){

        [Windows.Forms.MessageBox]::Show("Output folder cannot be the same as the source","Invalid selection","OK","Warning")
    }else{
        if($Folder){
            $UIControls.txt_Output.Text = $Folder
            $UIControls.txt_Output.Foreground="Black"
            $Script:Output_Folder = $Folder
        }
        Write-TxtLog "Selected output folder '$($Script:Output_Folder)'"
    }
   
    Test-Page1  # Are all required fields complete on this page?
})

$UIControls.combo_language.Add_SelectionChanged({
    $script:Language = $UIControls.combo_language.SelectedItem
    $script:LanguageCode = $Script:LangCodes | Where-Object{$_.DisplayName -eq $UIControls.combo_language.SelectedItem} | Select-Object -ExpandProperty Code
    Write-TxtLog "Selected language code '$($script:LanguageCode)'"

    Format-DisplayName
    
})

$UIControls.combo_Architecture.Add_SelectionChanged({
    $script:Architecture = $UIControls.combo_Architecture.SelectedItem
    Write-TxtLog "Selected architecture '$($script:Architecture)'"

    if($script:Architecture -eq 'x86'){
        # Use 32-bit PowerShell on an x86 system and 64-bit PowerShell otherwise
        $Script:Win32InstallCmd = $Script:Win32InstallCmd.Replace('sysnative','System32')
        $Script:Win32UninstallCmd = $Script:Win32UninstallCmd.Replace('sysnative','System32')
    }else{
        $Script:Win32InstallCmd = $Script:Win32InstallCmd.Replace('System32','sysnative')
        $Script:Win32UninstallCmd = $Script:Win32UninstallCmd.Replace('System32','sysnative')
    }
    Write-TxtLog "Install cmd now '$Script:Win32InstallCmd'"
    Write-TxtLog "Uninstall cmd now '$Script:Win32UninstallCmd'"

    Format-DisplayName            
    
})

$UIControls.txt_PubName.Add_TextChanged({
    $Script:Publisher = $UIControls.txt_PubName.Text.Trim()
    Write-TxtLog "Publisher changed to $($Script:Publisher)"

    $UIControls.txt_DisplayName.Text = [String]::Format("{0} {1} {2} P{3}",$Script:Publisher,$Script:AppName,$Script:Version,$Script:PkgNum)
    
    Test-Page2 # Are all required fields complete on this page?
})

$UIControls.txt_AppName.Add_TextChanged({
    $Script:AppName = $UIControls.txt_AppName.Text.Trim()
    Write-TxtLog "AppName changed to $($Script:AppName)"
    $UIControls.txt_DisplayName.Text = [String]::Format("{0} {1} {2} P{3}",$Script:Publisher,$Script:AppName,$Script:Version,$Script:PkgNum)

    Test-Page2 # Are all required fields complete on this page?
})

$UIControls.txt_Version.Add_TextChanged({
    $Script:Version = $UIControls.txt_Version.Text.Trim()
    Write-TxtLog "Version changed to $($Script:Version)"

    $UIControls.txt_DisplayName.Text = [String]::Format("{0} {1} {2} P{3}",$Script:Publisher,$Script:AppName,$Script:Version,$Script:PkgNum)
    
    Test-Page2 # Are all required fields complete on this page?
})

$UIControls.txt_PkgNum.Add_TextChanged({
    $Script:PkgNum = $UIControls.txt_PkgNum.Text.Trim()
    Write-TxtLog "Pkgnum changed to $($Script:PkgNum)"

    $UIControls.txt_DisplayName.Text = [String]::Format("{0} {1} {2} P{3}",$Script:Publisher,$Script:AppName,$Script:Version,$Script:PkgNum)

    Test-Page2 # Are all required fields complete on this page?
})

$UIControls.txt_DisplayName.Add_TextChanged({

    Test-DisplayName
})

$UIControls.txt_Description.Add_TextChanged({
    $Script:Description = $UIControls.txt_Description.Text.Trim()
    
    Test-Page2 # Are all required fields complete on this page?
})

$UIControls.combo_Dependency.Add_DropDownOpened({
   
})

$UIControls.combo_Dependency.Add_SelectionChanged({
    # Currently the IntuneWin32app module doesn't support setting Dependency and Supercedence
    # Although this is now supported in the admin console
    if($UIControls.combo_Dependency.SelectedItem -ne 'None'){

        $Script:Dependency = $Script:Win32Apps[$UIControls.combo_Dependency.SelectedItem]
        $UIControls.combo_Supercedence.IsEnabled = $False
        
    }else{
        $Script:Dependency='None'
        $UIControls.combo_Supercedence.IsEnabled = $True
    }

    Write-TxtLog "Selected dependency changed to '$($Script:Dependency)'"
 })

 $UIControls.combo_Supercedence.Add_SelectionChanged({
    # Currently the IntuneWin32app module doesn't support setting both Dependency and Supercedence
    # Although this is now supported in the admin console
    if($UIControls.combo_Supercedence.SelectedItem -ne 'None'){

        $Script:Supercedence = $Script:Win32Apps[$UIControls.combo_Supercedence.SelectedItem]
        $UIControls.combo_Dependency.IsEnabled = $False
        
    }else{
        $Script:Supercedence='None'
        $UIControls.combo_Dependency.IsEnabled = $True
    }
    Write-TxtLog "Selected supercedence changed to '$($Script:Supercedence)'"

 })

$UIControls.txt_Owner.Add_KeyUp({
    
    if([string]::IsNullOrEmpty($UIControls.txt_Owner.Text.Trim())){

        # Text in textbox was deleted so clear the lookup list
        $Script:OwnerTimer.Stop()
        $Script:OwnerTimer.Dispose()
        $UIControls.list_OwnerLookup.Items.Clear()
        $Script:OwnerLookup=''

    }elseif($null -eq $Script:OwnerTimer){

        # First time a key has been pressed. Start a timer to minimise multiple lookups on each keypress
        $Script:OwnerTimer = New-Object System.Windows.Forms.Timer
        $Script:OwnerTimer.Enabled = $true
        $Script:OwnerTimer.Interval = 600
        $Script:OwnerTimer.Add_Tick({
            
            $Script:OwnerTimer.Stop()
            Write-TxtLog "Owner lookup timer code"
            
            $UIControls.MainWindow.Dispatcher.Invoke([action]{
                $CurrentCursor = $UIControls.MainWindow.Cursor
                $UIControls.MainWindow.Cursor = [System.Windows.Input.Cursors]::Wait
            })

            $combo_text = $UIControls.txt_Owner.Text.Trim()
            if($UIControls.txt_Owner.Text.Trim() -ne $Script:OwnerLookup -and -not([string]::IsNullOrEmpty($UIControls.txt_Owner.Text.Trim()))){
                $Script:OwnerLookup = $UIControls.txt_Owner.Text.Trim()
                Find-Owner
            }else{
                $Script:OwnerLookup=''
            }
            $UIControls.MainWindow.Dispatcher.Invoke([action]{
                $UIControls.MainWindow.Cursor = $CurrentCursor
            })
        })
    }else{
        # 2nd or subsequent keypress. 
        # Keep reseting the timer until user has stopped typing. Then do the lookup
        $Script:OwnerTimer.Stop()
        $Script:OwnerTimer.Start()
    }
})

$UIControls.list_OwnerLookup.Add_SelectionChanged({
    # Add the Lookup list selected item the text box
    Reset-StatusBar
    $UIControls.txt_Owner.Text = $UIControls.list_OwnerLookup.SelectedItem
    $UIControls.btn_Owner.IsEnabled=$True
    Write-TxtLog "Selected owner '$($UIControls.list_OwnerLookup.SelectedItem)'"
})

$UIControls.btn_Owner.Add_Click({
    $UIControls.btn_Owner.IsEnabled=$False
    # Add the selected entry to the OwnerAdded list (if not already in the list). Make sure it is a UPN (contains @)
    if($UIControls.txt_Owner.Text.Trim() -ne '' -and -not($UIControls.list_OwnerAdded.items.contains($UIControls.txt_Owner.Text.Trim())) -and $UIControls.txt_Owner.Text.Trim() -match '@'){

        $UIControls.list_OwnerAdded.Items.Add($UIControls.txt_Owner.Text.Trim())
        $Script:Owners=[Array]$UIControls.list_OwnerAdded.Items
        Write-txtLog "Number of owners now = '$(($Script:Owners).Count)'"
        Reset-StatusBar

        $UIContros.txt_Owner.Text = ''
        $UIControls.list_OwnerLookup.items.Clear()
        $Script:OwnerLookup=''

    }elseif($UIControls.list_OwnerAdded.items.contains($UIControls.txt_Owner.Text.Trim())){
        $UIControls.txt_Status.Foreground = 'Red'
        $UIControls.txt_Status.Text='Owner entry already exists'
    }

    if($UIControls.list_OwnerAdded.Items.Count -ge 2){
        $UIControls.txt_Owner.IsReadOnly = $True
        $UIControls.btn_Owner.IsEnabled = $False
    }
    Test-Page3
})

$UIControls.btn_ClearOwner.Add_Click({
    Write-txtLog "Clicked button Clear Owner"
    $UIControls.list_OwnerAdded.Items.Clear()
    $UIControls.txt_Owner.IsReadOnly = $False
    $UIControls.btn_Owner.IsEnabled = $True
    $Script:OwnerLookup = ''
    $Script:Owners.Clear()
    Test-Page3
})

 $UIControls.btn_WrapperFiles.Add_Click({
    # Copy Wrapper Scripts from template folder to package source folder
    # Replace %Text% tokens in wrapper scripts with variables
    # Uses a separate runspace
    Write-TxtLog "Clicked button 'Update Wrapper Scripts'"
    Update-WrapperScripts
 })

 $UIControls.btn_IntuneWin.Add_Click({
    # Create .intunewinpackage file using a separate runspace     
    Write-TxtLog "Clicked button 'Create Win32 App Package'"
    New-IntuneWin
 })

 $UIControls.btn_CreateGroups.Add_Click({
    # Creates AAD app groups using a separate runspace
    Write-TxtLog "Clicked button 'Create App Groups'"
    New-AppGroups
 })

 $UIControls.btn_CreateWin32App.Add_Click({
    # Creates the Intune Win32App using a separate runspace
    Write-TxtLog "Clicked button 'Create Win32 App'"
    $UIControls.Btn_Previous.IsEnabled=$False  # no going back now
    New-Win32App
 })

 $UIControls.btn_Dependency.Add_Click({
    # Adds a dependency to the Win32App using a separate runspace
    Write-TxtLog "Clicked button 'Configure Dependency'"
    Add-Dependency
 })

 $UIControls.btn_Supercedence.Add_Click({
    # Adds a supercedence to the Win32App using a separate runspace
    Write-TxtLog "Clicked button 'Configure Supercedence'"
    Add-Supercedence
 })

 $UIControls.btn_Assignment.Add_Click({
    # Assigns the Required, Available and Uninstall groups using a separate runspace
    Write-TxtLog "Clicked button 'Assign Groups'"
    Set-AssignmentGroups
 })

 #ENDREGION
