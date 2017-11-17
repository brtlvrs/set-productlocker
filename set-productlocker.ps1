<#	
    .NOTES
    Script originaly created by Brian graf. Modified by Bart Lievers.
	===========================================================================
	 Created on:   	11/3/2015 2:59 PM
	 Created by:   	Brian Graf
     Modified by:   Bart Lievers
	===========================================================================
	.DESCRIPTION
		Assuming you have:
    downloaded Plink.EXE
    created a folder on a shared Datastore and placed the VMtools files in it 
    and your DNS is setup to resolve your hostnames,
     this will allow you to configure all of your hosts to use a shared 
     productlocker for VMware tools. 
#>

# Query all datastores that are currently accessed by more than one ESXi Host, using out-gridview
$datastore=Get-Datastore | where {$_.ExtensionData.Summary.MultipleHostAccess} | Out-GridView -Title "Please select a datastore" -OutputMode Single

# Display hosts that are connected to the datastore
$datastore | get-vmhost  | sort name | ft -AutoSize

# See if PSDrive 'PL:' exists, if it does, remove it
if (test-path 'PL:') {Remove-PSDrive PL -Force}

# Create new PSDrive to allow us to interact with the datastore
New-PSDrive -Location $Datastore -Name PL -PSProvider VimDatastore -Root '\' | out-null

# Change Directories to the new PSDrive
cd PL:

#Select rootfolder that contains the productlocker files, using out-gridview
$selection2=(get-childitem | ?{ $_.PSIsContainer} | sort name |out-gridview -title "Please select a folder" -OutputMode Single).name
if (Test-Path /$selection2){

    # if floppies folder exists, and has more than 1 item inside, move on
    if (Test-Path /$selection2/floppies) {
        Write-Host "Floppy Folder Exists"-ForegroundColor Green 
        $floppyitems = Get-ChildItem /$selection2/floppies/
        if ($floppyitems.count -ge 1) {
            Write-Host "($($floppyitems.count)) Files found in floppies folder" -ForegroundColor Green 
        } 
        # if there is not at least 1 file, throw...
        else {
            cd c:\
            Remove-PSDrive PL -Force
            Throw "No files found in floppies folder. please add files and try again"
        }
        } 
    # if the folder doesn't exist, throw...
    else {
            cd c:\
            Remove-PSDrive PL -Force
            Throw "it appears the floppies folder doesn't exist. add the floppies and vmtools folders with their respective files to the shared datastore"
    }
    # if vmtools folder exists, and has more than 1 item inside, move on
    if (Test-Path /$selection2/vmtools) {
        Write-host "vmtools Folder Exists" -ForegroundColor Green 
        $vmtoolsitems = Get-ChildItem /$selection2/vmtools/
        if ($vmtoolsitems.count -ge 1) {
            Write-Host "($($vmtoolsitems.count)) Files found in vmtools folder" -ForegroundColor Green 
        } 
        else {
            cd c:\
            Remove-PSDrive PL -Force
            Throw "No files found in vmtools folder. please add files and try again"
        }
        }
    # if the folder doesn't exist, throw...
    else {
        cd c:\
        Remove-PSDrive PL -Force
        Throw "it appears the vmtools folder doesn't exist. add the floppies and vmtools folders with their respective files to the shared datastore"
    }
}

# Congrats message at the end of checking the folder structure
Write-host "It appears the folders are setup correctly..." -ForegroundColor Green

# ------------ NEW MENU FOR SETTING VARIABLES ON HOSTS ------------
$title = "Set UserVars.ProductLockerLocation on Hosts"
$message = "Do you want to set this UserVars.ProductLockerLocation on all hosts that have access to Datastore [$selection]?"
$Y = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Yes - Set this on all hosts that see this datastore"
$N = New-Object System.Management.Automation.Host.ChoiceDescription "&No","No - Do Not set this on all hosts that see this datastore"
$options = [System.Management.Automation.Host.ChoiceDescription[]]($Y,$N)
$Result = $host.ui.PromptForChoice($title,$message,$options,0)
# -----------------------------------------------------------------

# Setting ProductLockerLocation on Hosts
Switch ($Result) {
    "0" {
        # Full Path to ProductLockerLocation
        Write-host "Full path to ProductLockerLocation: [vmfs/volumes/$($datastore.name)/$selection2]" -ForegroundColor Green
        # Set value on all hosts that access shared datastore
        Get-AdvancedSetting -entity (Get-VMHost -Datastore $datastore | sort name) -Name 'UserVars.ProductLockerLocation'| Set-AdvancedSetting -Value "vmfs/volumes/$($datastore.name)/$selection2" -Confirm:$false
    }
    "1" { 
        Write-Host "By not choosing `"Yes`" you will need to manually update the UserVars.ProductLockerLocation value on each host that has access to Datastore [$($datastore.name)]" -ForegroundColor Yellow
    }

}

# Change drive location to c:\
cd c:\

# Remove the PS Drive for cleanliness
Remove-PSDrive PL -Force

Write-host ""
Write-host ""
Write-host "The final portion of this is to update the SymLinks in the hosts to point to our new ProductLockerLocation. This can be set by either rebooting your ESXi Hosts, or we can set this with remote SSH sessions via Plink.exe" -ForegroundColor Yellow

# ------------ NEW MENU FOR SETTING VARIABLES ON HOSTS ------------
$title1 = "Update SymLinks on ESXi Hosts"
$message1 = "Would you like to have this script do remote SSH sessions instead of reboots?"
$Y1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes - Tell me more","Yes - Continue on with this process "
$N1 = New-Object System.Management.Automation.Host.ChoiceDescription "&No - I'll just restart my hosts to update the link instead","No - Exit this script"
$options1 = [System.Management.Automation.Host.ChoiceDescription[]]($Y1,$N1)
$Result1 = $host.ui.PromptForChoice($title1,$message1,$options1,0)
# -----------------------------------------------------------------


# Setting ProductLockerLocation on Hosts
Switch ($Result1) {
    "0" {
        # Full Path to Plink.exe
        do {$plink = read-host "What is the full path to Plink.exe (ex: c:\temp\plink.exe)?"}
        until (Test-Path $plink)

        Write-host ""
        Write-host "This script assumes all ESXi Hosts have the same username and password. If this is not the case you will need to modify this script to accept a CSV with other info" -ForegroundColor Yellow  
        
        # Get encrypted credentials from user for ESXi Hosts
        $creds = (Get-Credential -Message "What is the login for your ESXi Hosts?")
     
        $username = $creds.UserName
        $PW = $creds.GetNetworkCredential().Password

        Write-host ""

        # Each host needs to have SSH enabled to continue
        $SSHON = @()
        $VMhosts = Get-VMHost -Datastore $datastore | sort name 
        
        # Foreach ESXi Host, see if SSH is running, if it is, add the host to the array
        $VMHosts | % {
        if ($_ |Get-VMHostService | ?{$_.key -eq "TSM-SSH"} | ?{$_.Running -eq $true}) {
            $SSHON += $_.Name
            Write-host "SSH is already running on $($_.Name). adding to array to not be turned off at end of script" -ForegroundColor Yellow
        }
        
        # if not, start SSH
        else {
            Write-host "Starting SSH on $($_.Name)" -ForegroundColor Yellow
            Start-VMHostService -HostService ($_ | Get-VMHostService | ?{ $_.Key -eq "TSM-SSH"} ) -Confirm:$false | out-null
        }
        }
         
        #Start PLINK COMMANDS
        $plinkfolder = Get-ChildItem $plink

        # Change directory to Plink location for ease of use
        cd $plinkfolder.directoryname
        $VMHOSTs | foreach {
            
            # Run Plink remote SSH commands for each host
            Write-host "Running remote SSH commands on $($_.Name)." -ForegroundColor Yellow
            Echo Y | ./plink.exe $_.Name -pw $PW -l $username 'rm /productLocker'
            Echo Y | ./plink.exe $_.Name -pw $PW -l $username "ln -s /vmfs/volumes/$($datastore.name)/$selection2 /productLocker"
        }

        write-host ""
        write-host "Remote SSH Commands complete" -ForegroundColor Green
        write-host ""

        # Turn off SSH on hosts where SSH wasn't already enabled
        $VMhosts | foreach { 
            if ($SSHON -notcontains $_.name) {
                Write-host "Turning off SSH for $($_.Name)." -ForegroundColor Yellow
                Stop-VMHostService -HostService ($_ | Get-VMHostService | ?{ $_.Key -eq "TSM-SSH"} ) -Confirm:$false | Out-Null
            } else {
                Write-host "$($_.Name) already had SSH on before running the script. leaving SSH running on host..." -ForegroundColor Yellow
            }
        } 
    }
    "1" { 
        Write-Host "By not choosing `"Yes`" you will need to restart all your ESXi Hosts to have the symlink update and point to the new shared product locker location." -ForegroundColor Yellow
    }

}
$n = $VMhosts.count
$s = 150 * $n
$time =  [timespan]::fromseconds($s)
$showTime = ("{0:hh\:mm\:ss}" -f $time)
Write-host ""
Write-Host "*******************
  Script Complete
*******************
You just saved yourself roughly $showTime by automating this task
" -ForegroundColor Green