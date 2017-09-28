# Script Parameters for <scriptname>.ps1
<#
    Author             : <Script Author>
    Last Edit          : <Initials> - <date>
#>

#region Custom Type definitions

#-- Type definitions needed for syslog function
Add-Type -TypeDefinition @"
       public enum Syslog_Facility
       {
               kern,
               user,
               mail,
               system,
               security,
               syslog,
               lpr,
               news,
               uucp,
               clock,
               authpriv,
               ftp,
               ntp,
               logaudit,
               logalert,
               cron,
               local0,
               local1,
               local2,
               local3,
               local4,
               local5,
               local6,
               local7,
       }
"@
 
Add-Type -TypeDefinition @"
       public enum Syslog_Severity
       {
               Emergency,
               Alert,
               Critical,
               Error,
               Warning,
               Notice,
               Informational,
               Debug
          }
"@
#endregion


@{
    #-- default script parameters
        LogPath="D:\beheer\logs"
        LogDays=5 #-- Logs older dan x days will be removed

    #-- Syslog settings
        SyslogServer="syslog.shire.lan" #-- syslog FQDN or IP address

    #-- disconnect viServer in exit-script function
        DisconnectviServerOnExit=$true

    #-- vSphere vCenter FQDN
        vCenter="value" #-- vCenter FQDN
}