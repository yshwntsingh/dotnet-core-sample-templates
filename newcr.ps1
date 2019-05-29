####################
#Enable PS Remoting#
####################

Enable-PSRemoting –force

#############################################
#Add Firewall Rule to allow external traffic#
#############################################

New-NetFirewallRule -DisplayName InterVPC -Direction Inbound -Action Allow -EdgeTraversalPolicy Allow -Protocol Any -LocalPort Any

#############
#Disable UAC#
#############

Set-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name ConsentPromptBehaviorAdmin -Value 0

########################
#Create new directories#
########################

New-Item -Path c:\script -ItemType Directory
New-Item -Path c:\binary -ItemType Directory

#############################
#Download Binary and Scripts#
#############################

#Map Azure File Share

$acctKey = ConvertTo-SecureString -String "pxdQjp5vQRcuZNyySqKk/Bp9JuTPgLXi6fba6edF6gDU6DXSX6fnE6AVQlNH++yVXBSn2przWqx00j9DO/agXg==" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential -ArgumentList "Azure\aaebinary", $acctKey
New-PSDrive -Name Z -PSProvider FileSystem -Root "\\aaebinary.file.core.windows.net\binary" -Credential $credential -Persist

#Download Client
copy "z:\-00-Mo-22-00_Automation_Anywhere_Enterprise_Client_11.3.2.1.exe" "c:\binary\AA_Client.exe"

#Download CR
copy "z:\Automation Anywhere Enterprise_11.3.1.exe" "c:\binary\AA_CR.exe"

#Download SQL
copy "z:\SQLServer2017-SSEI-Expr.exe" "c:\binary\AA_SQL.exe"

#Download SSMS
copy "z:\SSMS-Setup-ENU.exe" "c:\binary\AA_SSMS.exe"

#Download Config Files
copy "z:\AA.Settings.xml" "c:\script\AA.Settings.xml"
copy "z:\ConfigurationFile.ini" "c:\script\ConfigurationFile.ini"
copy "z:\EnableMixedMode.sql" "C:\script\EnableMixedMode.sql"
copy "z:\EnableSA.sql" "C:\script\EnableSA.sql"

#####################
#Client Installation#
#####################


Start-Sleep -Seconds 60

Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force

cd c:\binary
 .\AA_Client.exe /S /v/qn

#wait for 30 seconds
Start-Sleep -Seconds 30

##########################################
#Creating desktop and startmenu shortcuts#
##########################################

$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("C:\Users\Default\Desktop\Automation Anywhere.lnk")
$Shortcut.TargetPath = "C:\Program Files (x86)\Automation Anywhere\Enterprise\Client\Automation Anywhere.exe"
$Shortcut.Save()

$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Automation Anywhere Enterprise Client\Automation Anywhere.lnk")
$Shortcut.TargetPath = "C:\Program Files (x86)\Automation Anywhere\Enterprise\Client\Automation Anywhere.exe"
$Shortcut.Save()


##########################
#Starting Client Services#
##########################


#wait for 5 Minutes
Start-Sleep -Seconds 300

#Update CR Address in Clinet Settings

cd ~
cd "Documents\Automation Anywhere Files"
copy c:\script\AA.Settings.xml .\AA.Settings.xml

$clientsetting = ".\AA.Settings.xml"

(Get-Content $clientsetting) -replace "<restserviceurl>", "<restserviceurl>http://$env:COMPUTERNAME" | Set-Content $clientsetting

#start the services
Start-Service AAE_AutoLoginService_v11
Start-Service AAE_ClientService_v11
Start-Service AAE_SchedulerService_v11



#############
#Install SQL#
#############

cd c:\binary

.\AA_SQL.exe /ENU /IAcceptSqlServerLicenseTerms /Quiet /HideProgressBar /ConfigurationFile=c:\script\ConfigurationFile.ini /Action=Install /InstallPath="c:\Program Files\Microsoft SQL Server"

#wait for 7 Minutes
Start-Sleep -Seconds 420

$env:PSModulePath = $env:PSModulePath + ";C:\Program Files (x86)\Microsoft SQL Server\140\Tools\PowerShell\Modules"

#Wait for 30 seconds
Start-Sleep -Seconds 30

#Loading SQLPS environment
Import-Module SQLPS -DisableNameChecking -Force


#Initializing WMI object and Connect to the instance using SMO
($Wmi = New-Object ('Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer') $env:COMPUTERNAME)
($uri = "ManagedComputer[@Name='$env:COMPUTERNAME']/ ServerInstance[@Name='SQLEXPRESS']/ServerProtocol[@Name='Tcp']")


#Getting settings
($Tcp = $wmi.GetSmoObject($uri))
$Tcp.IsEnabled = $true
($Wmi.ClientProtocols)
$wmi.GetSmoObject($uri + "/IPAddress[@Name='IPAll']").IPAddressProperties


#Setting TCP Port as 1433
$wmi.GetSmoObject($uri + "/IPAddress[@Name='IPAll']").IPAddressProperties[1].Value="1433"


#Save properties
$Tcp.Alter()

#Enable SA
cd "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn"
.\SQLCMD.EXE -E -S localhost\SQLEXPRESS -i "C:\script\EnableSA.sql"

#Enable Mixed Mode Authentication
.\SQLCMD.EXE -E -S localhost\SQLEXPRESS -i "C:\script\EnableMixedMode.sql"

#Restart SQL Service
Restart-Service "SQL Server (SQLEXPRESS)"

##############
#Install SSMS#
##############

#wait for 30 seconds
Start-Sleep -Seconds 30

cd c:\binary
.\AA_SSMS.exe /Install /Quiet /Norestart /log ssmslog.txt

#wait for 8 Minutes
Start-Sleep -Seconds 480


############
#Install CR#
############

#wait for 30 seconds
Start-Sleep -Seconds 30

$cr_port=80
$db_server="localhost\sqlexpress"
$cr_db_name="CRDB-NEW"
$bi_db_name="BotInsight"
$db_user="sa"
$db_pwd="Automat!0n#2019"
$installation_path="C:\Program Files\Automation Anywhere"
$static_installation_path="\Enterprise\"""""
$silent_details=" /s ","v""" -join "/"
$installpath_details= "/qn INSTALLDIR=\"""
$custom_details=" /vAA_SETUPTYPE=Custom /vAA_CUSTOMMODETYPE=1"
$port_cluster_details=" /vAA_SETCLUSTERMODE=0 /vAA_CRLISTENPORT=$cr_port"
$service_details=" /vAA_CRSETLOCALSERVICECRED=0"
$db_details=" /vAA_SQLSERVERAUTHTYPE=true /vIS_SQLSERVER_SERVER=$db_server /vIS_SQLSERVER_USERNAME=$db_user /vIS_SQLSERVER_PASSWORD=$db_pwd /vIS_SQLSERVER_DATABASE1=$bi_db_name /vIS_SQLSERVER_DATABASE=$cr_db_name /vIS_SQLSERVER_AUTHENTICATION=1 /vAA_SQLSERVERAUTHMODE=1"
$other=" /vAA_CRWCHTTPPORT=80 /vAA_CRWCHTTPSPORT=443 /vAA_CRSELFSIGNCERT=1 /vLAUNCHPROGRAM=1 /v""/L*v log.txt"""
$final_commandline = -join($silent_details,$installpath_details,$installation_path,$static_installation_path,$custom_details,$port_cluster_details,$service_details,$db_details,$other)
$a = "c:\binary\AA_CR.exe"
$processdetail=(Start-Process -FilePath $a -ArgumentList $final_commandline -Wait -PassThru).ExitCode

