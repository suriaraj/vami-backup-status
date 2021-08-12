#################################################################################

##

## VAMI Backup and Health Status

## Created by Suriaraj Dhayalan 

## Date : 08 Aug 2021

## Version : 1.0

## Email: d.suriaraj23@gmail.com  

## This scripts checks the vCenter server Health Status and Backup Status

## works for single or multiple vcenter's. 

## modification or redistribution is allowed with proper credits to post

##

################################################################################

 

#checking and removing html file

if (get-item \fakepath\result.html -ErrorAction ignore) {Remove-Item \fakepath\result.html}

$Result =@()

cls

##Skipping/Accepting SSL/TLS validation

add-type @"

    using System.Net;

    using System.Security.Cryptography.X509Certificates;

    public class TrustAllCertsPolicy : ICertificatePolicy {

        public bool CheckValidationResult(

            ServicePoint srvPoint, X509Certificate certificate,

            WebRequest request, int certificateProblem) {

            return true;

        }

    }

"@

[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

#vc backup validation

foreach ($vcenter in (Get-Content -Path \fakepath\host.txt))

{

$BaseUri = "https://$vcenter/rest/"

$SessionUri = $BaseUri + "com/vmware/cis/session"

#credentials

$username = "myuser"

$password = Get-Content \fakepath\pass.ssh

$secst = $password | ConvertTo-SecureString -AsPlainText -Force

$creds=New-Object System.Management.Automation.PSCredential -ArgumentList $username,$secst

$auth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Creds.UserName+':'+($secst=$Creds.GetNetworkCredential().Password)))

$header = @{

  'Authorization' = "Basic $auth"

}

$authResponse = (Invoke-RestMethod -Method Post -Headers $header -Uri $SessionUri).Value

$sessionHeader = @{"vmware-api-session-id" = $authResponse}

##checking backup job id

$bjlist = Invoke-Restmethod -Method Get -Headers $sessionHeader -Uri ($BaseUri + "appliance/recovery/backup/job")

##selecting last recent job id

$bj=$bjlist.value | Select-Object -first 1

##collecting job id status

$bjstat = Invoke-Restmethod -Method Get -Headers $sessionHeader -Uri ($BaseUri + "appliance/recovery/backup/job/"+$bj)

##collecting vCenter Overla health and last checked date

$overhealth = Invoke-Restmethod -Method Get -Headers $sessionHeader -Uri ($BaseUri + "/appliance/health/system")

$lastcheckdate = Invoke-Restmethod -Method Get -Headers $sessionHeader -Uri ($BaseUri + "/appliance/health/system/lastcheck")

$memory = Invoke-Restmethod -Method Get -Headers $sessionHeader -Uri ($BaseUri + "/appliance/health/mem")

$dbstat = Invoke-Restmethod -Method Get -Headers $sessionHeader -Uri ($BaseUri + "/appliance/health/database-storage")

$CPU = Invoke-Restmethod -Method Get -Headers $sessionHeader -Uri ($BaseUri + "/appliance/health/load")

$storage = Invoke-Restmethod -Method Get -Headers $sessionHeader -Uri ($BaseUri + "/appliance/health/storage")

$service = Invoke-Restmethod -Method Get -Headers $sessionHeader -Uri ($BaseUri + "/appliance/health/applmgmt")

$swap = Invoke-Restmethod -Method Get -Headers $sessionHeader -Uri ($BaseUri + "/appliance/health/swap")

#storing data to array

$Result += New-Object PSObject -Property @{

vCenter_Name = $vcenter

ID = $bjstat.value.id

State = $bjstat.value.state

Start_Time = $bjstat.value.start_time

End_Time = $bjstat.value.end_time

Progress = $bjstat.value.progress

OverallHealth = $overhealth.value

Lastcheckdate = $lastcheckdate.value

CPU = $cpu.value

Memory = $memory.value

Storage = $storage.value

DatabaseStorage = $dbstat.value

Service=$service.value

Swap=$swap.value

}

}

##converting to HTML

if($Result -ne $null)

{

$REPHTML = '<style type="text/css">

#Header{font-family:"Trebuchet MS", Arial, Helvetica, sans-serif;width:100%;border-collapse:collapse;}

#Header td, #Header th {font-size:14px;border:1px solid #3D85C6;padding:3px 7px 2px 7px;}

#Header th {font-size:14px;text-align:left;padding-top:5px;padding-bottom:4px;background-color:#073763;color:#fff;}

#Header tr.alt td {color:#000;background-color:#EAF2D3;}

</Style>'

##start of first table backup status

$REPHTML += "<HTML><BODY>

<b>Backup Status:</b></br>

<Table border=1 cellpadding=0 cellspacing=0 id=Header>

<TR>

<TH><B>Host Name</B></TH>

<TH><B>Backup Job ID</B></TD>

<TH><B>Status</B></TD>

<TH><B>Start Time Type</B></TH>

<TH><B>End Time</B></TH>

<TH><B>Progress</B></TH>

</TR>"

Foreach($Entry in $Result)

{

$REPHTML += "<TR>"

$REPHTML += "

<TD>$($Entry.vCenter_name)</TD>

<TD>$($Entry.ID)</TD>

<TD>$($Entry.State)</TD>

<TD>$($Entry.Start_Time)</TD>

<TD>$($Entry.End_Time)</TD>

<TD>$($Entry.Progress)</TD>

 

</TR>"

 

}

$REPHTML += "</Table></br></br></BODY></HTML>" ##end of first table

#start of second table health status

$REPHTML += "<HTML><BODY>

<b>Overall Health Status:</b></br>

<Table border=1 cellpadding=0 cellspacing=0 id=Header>

<TR>

<TH><B>Vcenter Name</B></TH>

<TH><B>OverallHealth</B></TH>

<TH><B>Last checked date</B></TD>

<TH><B>CPU Status</B></TD>

<TH><B>Memory Status</B></TH>

<TH><B>Storage Status</B></TH>

<TH><B>DatabaseStorage Status</B></TH>

<TH><B>Service Status</B></TH>

<TH><B>SWAP Memory Status</B></TH>

</TR>"

Foreach($Entry in $Result)

{

$REPHTML += "<TR>"

$REPHTML += "

<TD>$($Entry.vCenter_name)</TD>

<TD>$($Entry.OverallHealth)</TD>

<TD>$($Entry.Lastcheckdate)</TD>

<TD>$($Entry.CPU)</TD>

<TD>$($Entry.Memory)</TD>

<TD>$($Entry.Storage)</TD>

<TD>$($Entry.DatabaseStorage)</TD>

<TD>$($Entry.Service)</TD>

<TD>$($Entry.Swap)</TD>

</TR>"

 

}

$REPHTML += "</Table></BODY></HTML>" #end of second table

#convert to html file

$REPHTML | Out-File .\fakepath\result.html

}

#date variable to add report generated  date and time in email

$date =Get-Date

#moving the html data as raw content to append in email

$HTML_Report = get-content .\fakepath\result.html -raw

#body of them email

$Body = @"

Hi Team,</br></br>Please find the vCenter Daily Backup Report for $date </br></br> <b>vCenter Backup Report & Health Status: </b>$HTML_Report

</br><b>Regards,</br>

VMware Support Team.</b>

"@

#email function uses smtp

Send-MailMessage -From VMwareAdmin@myserver.com -to me@myserver.com -SmtpServer smtp.myserver.com -Body $body -BodyAsHtml -Subject "vCenter Daily Health & Backup Report"

 
#################################################################################

##

## Thanks to rudimartinsen for his wonderful post on how to use vami api's

## link to his blog https://rudimartinsen.com

##

################################################################################

 