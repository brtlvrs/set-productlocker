<#
.SYNOPSIS
   Allow all vSphere hosts to use a shared productlocker for vmware tools.
.DESCRIPTION
		Assuming you have:
    downloaded Plink.EXE
    created a folder on a shared Datastore and placed the VMtools files in it 
    and your DNS is setup to resolve your hostnames,
     this will allow you to configure all of your hosts to use a shared 
     productlocker for VMware tools. 
.EXAMPLE
    One or more examples for how to use this script
.NOTES
    File Name          : set-productlocker.ps1
    Author             : Bart Lievers / Brian Graf (original script)
    Prerequisite       : <Preruiqisites like
                         Min. PowerShell version : 2.0
                         PS Modules and version : 
                            PowerCLI - 6.0 R2
    Last Edit          : <Initials> - <date>

#>
[CmdletBinding()]

Param(
    #-- Define Powershell input parameters (optional)
    [string]$text

)

Begin{
    #-- initialize environment
    $DebugPreference="SilentlyContinue"
    $VerbosePreference="SilentlyContinue"
    $ErrorActionPreference="Continue"
    $WarningPreference="Continue"
    clear-host #-- clear CLi
    $ts_start=get-date #-- note start time of script
    if ($finished_normal) {Remove-Variable -Name finished_normal -Confirm:$false }

	#-- determine script location and name
	$scriptpath=get-item (Split-Path -parent $MyInvocation.MyCommand.Definition)
	$scriptname=(Split-Path -Leaf $MyInvocation.mycommand.path).Split(".")[0]

    #-- Load Parameterfile
    if (!(test-path -Path $scriptpath\parameters.ps1 -IsValid)) {
        write-warning "parameters.ps1 niet gevonden. Script kan niet verder."
        exit
    } 
    $P = & $scriptpath\parameters.ps1


#region for Private script functions
    #-- note: place any specific function in this region

    function exit-script 
    {
        <#
        .DESCRIPTION
            Clean up actions before we exit the script.
        #>
        [CmdletBinding()]
        param()

        #-- check why script is called and react apropiatly
        if ($finished_normal) {
            $msg= "Hooray.... finished without any bugs....."
            if ($log) {$log.verbose($msg)} else {Write-Verbose $msg}
        } else {
            $msg= "(1) Script ended with errors."
            if ($log) {$log.error($msg)} else {Write-Error $msg}
        }

        #-- General cleanup actions
        #-- disconnect vCenter connections if they exist
        if ((Get-Variable -Scope global -Name DefaultVIServers -ErrorAction SilentlyContinue) -and $P.DisconnectviServerOnExit  ) {
            Disconnect-VIServer -server * -Confirm:$false
        }
        #-- Output runtime and say greetings
        $ts_end=get-date
        $msg="Runtime script: {0:hh}:{0:mm}:{0:ss}" -f ($ts_end- $ts_start)  
        write-host $msg
        read-host "The End <press Enter to close window>."
        exit
    }

    function Send-SyslogMessage
    {
    <#
    .SYNOPSIS
    Sends a SYSLOG message to a server running the SYSLOG daemon
 
    .DESCRIPTION
    Sends a message to a SYSLOG server as defined in RFC 5424. A SYSLOG message contains not only raw message text,
    but also a severity level and application/system within the host that has generated the message.
 
    .PARAMETER Server
    Destination SYSLOG server that message is to be sent to
 
    .PARAMETER Message
    Our message
 
    .PARAMETER Severity
    Severity level as defined in SYSLOG specification, must be of ENUM type Syslog_Severity
 
    .PARAMETER Facility
    Facility of message as defined in SYSLOG specification, must be of ENUM type Syslog_Facility
 
    .PARAMETER Hostname
    Hostname of machine the mssage is about, if not specified, local hostname will be used
 
    .PARAMETER Timestamp
    Timestamp, myst be of format, "yyyy:MM:dd:-HH:mm:ss zzz", if not specified, current date & time will be used
 
    .PARAMETER UDPPort
    SYSLOG UDP port to send message to
 
    .INPUTS
    Nothing can be piped directly into this function
 
    .OUTPUTS
    Nothing is output
 
    .EXAMPLE
    Send-SyslogMessage mySyslogserver "The server is down!" Emergency Mail
    Sends a syslog message to mysyslogserver, saying "server is down", severity emergency and facility is mail
 
    .NOTES
    NAME: Send-SyslogMessage
    AUTHOR: Kieran Jacobsen
    LASTEDIT: 2014 07 01
    KEYWORDS: syslog, messaging, notifications
 
    .LINK
    https://github.com/kjacobsen/PowershellSyslog
 
    .LINK
    http://aperturescience.su
 
    #>
    [CMDLetBinding()]
    Param
    (
            [Parameter(mandatory=$true)] [String] $Server,
            [Parameter(mandatory=$true)] [String] $Message,
            [Parameter(mandatory=$true)] [Syslog_Severity] $Severity,
            [Parameter(mandatory=$true)] [Syslog_Facility] $Facility,
            [String] $Hostname,
            [String] $Timestamp,
            [int] $UDPPort = 514
    )
 
    # Create a UDP Client Object
    $UDPCLient = New-Object System.Net.Sockets.UdpClient
    try {$UDPCLient.Connect($Server, $UDPPort)}

    catch {
        write-host "No connection to syslog server"
        return
    }
 
    # Evaluate the facility and severity based on the enum types
    $Facility_Number = $Facility.value__
    $Severity_Number = $Severity.value__
    Write-Verbose "Syslog Facility, $Facility_Number, Severity is $Severity_Number"
 
    # Calculate the priority
    $Priority = ($Facility_Number * 8) + $Severity_Number
    Write-Verbose "Priority is $Priority"
 
    # If no hostname parameter specified, then set it
    if (($Hostname -eq "") -or ($Hostname -eq $null))
    {
            $Hostname = Hostname
    }
 
    # I the hostname hasn't been specified, then we will use the current date and time
    if (($Timestamp -eq "") -or ($Timestamp -eq $null))
    {
            $Timestamp = Get-Date -Format "yyyy:MM:dd:-HH:mm:ss zzz"
    }
 
    # Assemble the full syslog formatted message
    $FullSyslogMessage = "<{0}>{1} {2} {3}" -f $Priority, $Timestamp, $Hostname, $Message
 
    # create an ASCII Encoding object
    $Encoding = [System.Text.Encoding]::ASCII
 
    # Convert into byte array representation
    $ByteSyslogMessage = $Encoding.GetBytes($FullSyslogMessage)
 
    # If the message is too long, shorten it
    if ($ByteSyslogMessage.Length -gt 1024)
    {
        $ByteSyslogMessage = $ByteSyslogMessage.SubString(0, 1024)
    }
 
    # Send the Message
    $UDPCLient.Send($ByteSyslogMessage, $ByteSyslogMessage.Length)
 
    }
 
    function import-powercli
    {
        <#
        .SYNOPSIS
           Loading of all VMware modules and power snapins
        .DESCRIPTION

        .EXAMPLE
            One or more examples for how to use this script
        .NOTES
        #>
        [CmdletBinding()]

        Param(
        )

        Begin{

        }

        Process{
            #-- make up inventory and check PowerCLI installation
            $RegisteredModules=Get-Module -Name vmware* -ListAvailable -ErrorAction ignore | % {$_.Name}
            $RegisteredSnapins=get-pssnapin -Registered vmware* -ErrorAction Ignore | %{$_.name}
            if (($RegisteredModules.Count -eq 0 ) -and ($RegisteredSnapins.count -eq 0 )) {
                #-- PowerCLI is not installed
                if ($log) {$log.warning("Cannot load PowerCLI, no VMware Powercli Modules and/or Snapins found.")}
                else {
                write-warning "Cannot load PowerCLI, no VMware Powercli Modules and/or Snapins found."}
                #-- exit function
                return $false
            }

            #-- load modules
            if ($RegisteredModules) {
                #-- make inventory of already loaded VMware modules
                $loaded = Get-Module -Name vmware* -ErrorAction Ignore | % {$_.Name}
                #-- make inventory of available VMware modules
                $registered = Get-Module -Name vmware* -ListAvailable -ErrorAction Ignore | % {$_.Name}
                #-- determine which modules needs to be loaded, and import them.
                $notLoaded = $registered | ? {$loaded -notcontains $_}

                foreach ($module in $registered) {
                    if ($loaded -notcontains $module) {
                        Import-Module $module
                    }
                }
            }

            #-- load Snapins
            if ($RegisteredSnapins) {      
                #-- Exlude loaded modules from additional snappins to load
                $snapinList=Compare-Object -ReferenceObject $RegisteredModules -DifferenceObject $RegisteredSnapins | ?{$_.sideindicator -eq "=>"} | %{$_.inputobject}
                #-- Make inventory of loaded VMware Snapins
                $loaded = Get-PSSnapin -Name $snapinList -ErrorAction Ignore | % {$_.Name}
                #-- Make inventory of VMware Snapins that are registered
                $registered = Get-PSSnapin -Name $snapinList -Registered -ErrorAction Ignore  | % {$_.Name}
                #-- determine which snapins needs to loaded, and import them.
                $notLoaded = $registered | ? {$loaded -notcontains $_}

                foreach ($snapin in $registered) {
                    if ($loaded -notcontains $snapin) {
                        Add-PSSnapin $snapin
                    }
                }
            }
            #-- show loaded vmware modules and snapins
            if ($RegisteredModules) {get-module -Name vmware* | select name,version,@{N="type";E={"module"}} | ft -AutoSize}
              if ($RegisteredSnapins) {get-pssnapin -Name vmware* | select name,version,@{N="type";E={"snapin"}} | ft -AutoSize}

        }

        End{

        }

    }

#endregion
}

Process{

    # check if PowerCLi is loaded and connect to vCenter
    if (Get-module vmware.VimAutomation.core  ){
        write-host "PowerCLi detected, nice"
    } elseif (get-module -ListAvailable VMware.VimAutomation.Core) {
        write-host "No PowerCLi loaded, try loading PowerCLi"
        get-module -ListAvailable vmware* | Import-Module
    } else {
        write-host "PowerCLi not installed, exit script." -ForegroundColor Yellow
        exit-script
    }
    if (Get-module vmware.VimAutomation.core  ){
        write-host ("Connecting to vCenter "+ $p.vcenter)
        connect-viserver $p.vcenter
    } else {
        Write-host "Failed to load PowerCLi, exiting script." -ForegroundColor Yellow
        exit-script
    }

    # Query all datastores that are currently accessed by more than one ESXi Host, using out-gridview
    $datastore=Get-Datastore | where {$_.ExtensionData.Summary.MultipleHostAccess} | Out-GridView -Title "Please select a datastore" -OutputMode Single
    if ($datastore.count -ne 1) {
        write-host "No datastore selection, exiting script." -ForegroundColor Yellow
        exit-script
    }
    
    # display hosts that are connected to the selected datastore
    $datastore | get-vmhost | sort name | ft -AutoSize

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
                write-host "No files found in floppies folder. please add files and try again" -ForegroundColor Yellow
                exit-script
            }
            } 
        # if the folder doesn't exist, throw...
        else {
                cd c:\
                Remove-PSDrive PL -Force
                write-host  "it appears the floppies folder doesn't exist. add the floppies and vmtools folders with their respective files to the shared datastore" -ForegroundColor Yellow
                exit-script
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
                write-host  "No files found in vmtools folder. please add files and try again" -ForegroundColor Yellow
                exit-script
            }
            }
        # if the folder doesn't exist, throw...
        else {
            cd c:\
            Remove-PSDrive PL -Force
            write-host "it appears the vmtools folder doesn't exist. add the floppies and vmtools folders with their respective files to the shared datastore" -ForegroundColor Yellow
            exit-script
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
            Get-AdvancedSetting -entity (Get-VMHost -Datastore $datastore| sort name) -Name 'UserVars.ProductLockerLocation'| Set-AdvancedSetting -Value "vmfs/volumes/$($datastore.name)/$selection2"
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
            $VMhosts = Get-VMHost -Datastore $datastore| sort name 
            
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
                    Stop-VMHostService -HostService ($_ | Get-VMHostService | ?{ $_.Key -eq "TSM-SSH"} ) -Confirm:$false | out-null
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
}

End{
    #-- we made it, exit script.
    $finished_normal=$true
    exit-script
}
