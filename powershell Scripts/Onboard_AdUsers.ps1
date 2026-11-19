Import-Module ActiveDirectory

#  Setup folders and domain variables
New-Item -ItemType Directory -Force -Path "C:\Temp" | Out-Null
$CsvPath = "C:\Users\Administrator\Desktop\Temp\users.csv"
$DomainName = "iesegbue.com"
$DomainDN   = "DC=iesegbue,DC=com"
$CompanyOU  = "OU=iesegbue llc,$DomainDN"
$Cities     = @("Manchester", "London", "Preston")
$Departments = @("HR", "IT", "Sales")

#  Create Company, City, and Department OUs if missing
if (-not [adsi]::Exists("LDAP://$CompanyOU")) {
    New-ADOrganizationalUnit -Name "iesegbue llc" -Path $DomainDN
}

foreach ($City in $Cities) {
    $CityOU = "OU=$City,$CompanyOU"
    if (-not [adsi]::Exists("LDAP://$CityOU")) {
        New-ADOrganizationalUnit -Name $City -Path $CompanyOU
    }
    foreach ($SubFolder in @("computers", "users")) {
        $SubOU = "OU=$SubFolder,$CityOU"
        if (-not [adsi]::Exists("LDAP://$SubOU")) {
            New-ADOrganizationalUnit -Name $SubFolder -Path $CityOU
        }
    }
    foreach ($Dept in $Departments) {
        $DeptOU = "OU=$Dept,OU=users,$CityOU"
        if (-not [adsi]::Exists("LDAP://$DeptOU")) {
            New-ADOrganizationalUnit -Name $Dept -Path "OU=users,$CityOU"
        }
    }
}

# 3. Generate 30 random users and save to C:\Temp\users.csv
$FirstNames = @("Liam", "Olivia", "Noah", "Emma", "Oliver", "Ava", "Elijah", "Sophia", "James", "Isabella", "Lucas", "Mia", "Mason", "Charlotte", "Ethan", "Amelia", "Logan", "Harper", "Aiden", "Evelyn")
$LastNames  = @("Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez", "Taylor", "Thomas", "Moore", "Jackson", "Martin", "Lee", "Thompson", "White", "Harris", "Clark")

$CsvData = @()
$UsedUsernames = @{}

for ($i = 1; $i -le 30; $i++) {
    $First = Get-Random -InputObject $FirstNames
    $Last  = Get-Random -InputObject $LastNames
    $BaseUsername = ($First.Substring(0,1) + $Last).ToLower()
    $Username = $BaseUsername
    $Counter = 1
    while ($UsedUsernames.ContainsKey($Username)) {
        $Username = "$BaseUsername$Counter"
        $Counter++
    }
    $UsedUsernames[$Username] = $true

    $CsvData += [PSCustomObject]@{
        FirstName  = $First
        LastName   = $Last
        Username   = $Username
        Password   = "P@ssw0rd123!"
        City       = (Get-Random -InputObject $Cities)
        Department = (Get-Random -InputObject $Departments)
    }
}
$CsvData | Export-Csv -Path $CsvPath -NoTypeInformation

# 4. Import the CSV users into Active Directory
$Users = Import-Csv -Path $CsvPath
foreach ($User in $Users) {
    $TargetOU = "OU=$($User.Department),OU=users,OU=$($User.City),$CompanyOU"
    $DisplayName = "$($User.FirstName) $($User.LastName)"
    $UPN = "$($User.Username)@$DomainName"
    $SecurePassword = ConvertTo-SecureString $User.Password -AsPlainText -Force

    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($User.Username)'")) {
        $UserParams = @{
            Name                  = $DisplayName
            GivenName             = $User.FirstName
            Surname               = $User.LastName
            SamAccountName        = $User.Username
            UserPrincipalName     = $UPN
            Path                  = $TargetOU
            AccountPassword       = $SecurePassword
            Enabled               = $true
            ChangePasswordAtLogon = $false
        }
        New-ADUser @UserParams
        Write-Host "Created: $DisplayName ($UPN) -> $($User.City) / $($User.Department)" -ForegroundColor Green
    }
}