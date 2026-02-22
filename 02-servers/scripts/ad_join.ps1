#requires -Version 5.1
$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

$Log    = "C:\ProgramData\boot.log"
$Marker = "C:\ProgramData\bootstrap.domain_join.done"

function Write-Log {
  param([Parameter(Mandatory=$true)][string]$Message)
  $ts   = (Get-Date).ToString("s")
  $line = "$ts $Message"
  Add-Content -Path $Log -Value $line
  Write-Output $line
}

New-Item -ItemType Directory -Force -Path "C:\ProgramData" | Out-Null
New-Item -ItemType File -Force -Path $Log | Out-Null

Write-Log "bootstrap start"

if (Test-Path $Marker) {
  Write-Log "NOTE: Run-once marker exists ($Marker). Exiting."
  exit 0
}

Write-Log "Install AD management components (RSAT/GPMC/DNS tools)"
Install-WindowsFeature -Name GPMC,RSAT-AD-PowerShell,RSAT-AD-AdminCenter,RSAT-ADDS-Tools,RSAT-DNS-Server | Out-Null

Write-Log "Fetch domain join credentials from Secret Manager"
$secretJson   = gcloud secrets versions access latest --secret="admin-ad-credentials-mini"
$secretObject = $secretJson | ConvertFrom-Json
$password     = $secretObject.password | ConvertTo-SecureString -AsPlainText -Force
$username     = $secretObject.username
$cred         = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password

Write-Log "Join domain: ${domain_fqdn}"
Add-Computer -DomainName "${domain_fqdn}" -Credential $cred -Force -ErrorAction Stop
Write-Log "SUCCESS: Domain join initiated"

Write-Log "Grant RDP access to domain group"
$domainGroup = "MCLOUD\mcloud-users"
$maxRetries  = 10
$retryDelay  = 30

for ($i = 1; $i -le $maxRetries; $i++) {
  try {
    Add-LocalGroupMember -Group "Remote Desktop Users" -Member $domainGroup -ErrorAction Stop
    Write-Log "SUCCESS: Added $domainGroup to Remote Desktop Users"
    break
  }
  catch {
    Write-Log "WARN: Attempt $i failed; waiting $retryDelay seconds"
    Start-Sleep -Seconds $retryDelay
    if ($i -eq $maxRetries) { throw }
  }
}

New-Item -ItemType File -Force -Path $Marker | Out-Null
Write-Log "bootstrap complete; rebooting to finalize domain join"

shutdown /r /t 5 /c "Initial reboot to join domain" /f /d p:4:1