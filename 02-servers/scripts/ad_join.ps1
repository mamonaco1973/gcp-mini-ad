# ------------------------------------------------------------
# Install Active Directory Components
# ------------------------------------------------------------

# Suppress progress bars to speed up execution
$ProgressPreference = 'SilentlyContinue'

# Install required Windows Features for Active Directory management
Install-WindowsFeature -Name GPMC,RSAT-AD-PowerShell,RSAT-AD-AdminCenter,RSAT-ADDS-Tools,RSAT-DNS-Server

# ------------------------------------------------------------
# Join instance to active directory
# ------------------------------------------------------------

$secretJson = gcloud secrets versions access latest --secret="admin-ad-credentials"
$secretObject = $secretJson | ConvertFrom-Json
$password = $secretObject.password | ConvertTo-SecureString -AsPlainText -Force
$username = $secretObject.username
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password

Add-Computer -DomainName "${domain_fqdn}" -Credential $cred -Force -ErrorAction Stop
Write-Output "Successfully joined the domain."

# ------------------------------------------------------------
# Create OUs for AD specific groups and users
# ------------------------------------------------------------

Write-Output "Create new OU for local users"

New-ADOrganizationalUnit -Name "Users" -Path "OU=Cloud,DC=mcloud,DC=mikecloud,DC=com" -credential $cred
$usersPath = "OU=Users,OU=Cloud,DC=mcloud,DC=mikecloud,DC=com"

# ------------------------------------------------------------
# Create AD Groups for User Management
# ------------------------------------------------------------

Write-Output "Create local groups in new OU"

New-ADGroup -Name "mcloud-users" -GroupCategory Security -GroupScope Universal -Credential $cred -Path "$usersPath" -OtherAttributes @{gidNumber='10001'}
New-ADGroup -Name "india" -GroupCategory Security -GroupScope Universal -Credential $cred -Path "$usersPath" -OtherAttributes @{gidNumber='10002'}
New-ADGroup -Name "us" -GroupCategory Security -GroupScope Universal -Credential $cred -Path "$usersPath" -OtherAttributes @{gidNumber='10003'}
New-ADGroup -Name "linux-admins" -GroupCategory Security -GroupScope Universal -Credential $cred -Path "$usersPath" -OtherAttributes @{gidNumber='10004'}

# ------------------------------------------------------------
# Create AD Users and Assign to Groups
# ------------------------------------------------------------

# Initialize a counter for uidNumber
$uidCounter = 10000 

# Function to create an AD user from AWS Secrets Manager
function Create-ADUserFromSecret {
    param (
        [string]$SecretId,
        [string]$GivenName,
        [string]$Surname,
        [string]$DisplayName,
        [string]$Email,
        [string]$Username,
        [array]$Groups
    )

    # Increment the uidCounter for each new user
    $global:uidCounter++
    $uidNumber = $global:uidCounter

    $secretValue  = gcloud secrets versions access latest --secret="$SecretId"
    $secretObject = $secretValue | ConvertFrom-Json
    $password = $secretObject.password | ConvertTo-SecureString -AsPlainText -Force

    Write-Output "Create local user $UserName"

    # Create the AD user
    New-ADUser -Name $Username `
        -GivenName $GivenName `
        -Surname $Surname `
        -DisplayName $DisplayName `
        -EmailAddress $Email `
        -UserPrincipalName "$Username@${domain_fqdn}" `
        -SamAccountName $Username `
        -AccountPassword $password `
        -Enabled $true `
        -Credential $cred `
        -Path "$usersPath" `
        -PasswordNeverExpires $true `
        -OtherAttributes @{gidNumber='10001'; uidNumber=$uidNumber}
    
    Write-Output "Add user $UserName to groups"

    # Add the user to specified groups
    foreach ($group in $Groups) {
        Add-ADGroupMember -Identity $group -Members $Username -Credential $cred
    }
}

# Create users with predefined groups

Write-Output "Creating all local domain users"

Create-ADUserFromSecret "jsmith-ad-credentials" "John" "Smith" "John Smith" "jsmith@mcloud.mikecloud.com" "jsmith" @("mcloud-users", "us", "linux-admins")
Create-ADUserFromSecret "edavis-ad-credentials" "Emily" "Davis" "Emily Davis" "edavis@mikecloud.com" "edavis" @("mcloud-users", "us")
Create-ADUserFromSecret "rpatel-ad-credentials" "Raj" "Patel" "Raj Patel" "rpatel@mikecloud.com" "rpatel" @("mcloud-users", "india", "linux-admins")
Create-ADUserFromSecret "akumar-ad-credentials" "Amit" "Kumar" "Amit Kumar" "akumar@mikecloud.com" "akumar" @("mcloud-users", "india")

# ------------------------------------------------------------
# Grant RDP Access to All Users in "mcloud-users" Group
# ------------------------------------------------------------

Write-Output "Add users to the Remote Desktop Users Group"
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "mcloud-users"

# ------------------------------------------------------------
# Final Reboot to Apply Changes
# ------------------------------------------------------------

Write-Output "Finalize join with a reboot"

# Reboot the server to finalize the domain join and group policies
shutdown /r /t 5 /c "Initial reboot to join domain" /f /d p:4:1