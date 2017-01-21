<#
.SYNOPSIS
Applies best practices to an AD FS on Windows Server 2016 environment.

.DESCRIPTION
Applies none (or more) AD FS best practices to an AD FS on Windows Server 2016 environment.

Best practices are derived from this post: https://flamingkeys.com/ad-fs-windows-server-2016-best-practices/

IMPORTANT: This script will not undo any settings, only apply them if they are not already applied.

.PARAMETER EnableKeepMeSignedIn
Enables KMSI.

.PARAMETER EnableEndUserPasswordChange
Enables end-user password change at /adfs/portal/updatepassword.

.PARAMETER EnableWsTrust13WinTransport
Enables the /adfs/services/trust/13/windowstransport endpoint to allow WIA with ADAL.

.PARAMETER AddPasswordExpiryClaim
Not yet implemented

.PARAMETER AddAuthNMethodsClaim
Not yet implemented

.PARAMETER EnableExtranetLockout
Enables extranet lockout. Requires that the following parameters be provided:
    -ExtranetLockoutThreshold
    -ExtranetLockoutObservationWindow

.PARAMETER ExtranetLockoutThreshold
The number of sequential failed logins to permit before locking the user out. 
Should be lower than the AD lockout threshold.

.PARAMETER ExtranetLockoutObservationWindow
Number of minutes to lock a user out for after meeting the ExtranetLockoutThreshold value.

.PARAMETER ExtendTokenCertificateLifetime
Extend the token-signing and token-decrypting certificates to be valid for 5 years.

WARNING: this will break any relying party trusts in place and will require a metadata refresh on the relying party end.

.PARAMETER EnableVerboseLogging
Enables verbose logging within windows and the AD FS service

.EXAMPLE

.LINK
https://github.com/chrisbrownie/ApplyAdfsBestPractices

.NOTES
Written by Chris Brown

License:

The MIT License (MIT)

Copyright (c) 2017 Chris Brown

Permission is hereby granted, free of charge, to any person obtaining a copy 
of this software and associated documentation files (the "Software"), to deal 
in the Software without restriction, including without limitation the rights 
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all 
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
DEALINGS IN THE SOFTWARE.


#>

[CmdletBinding()]
Param(

    [Parameter()]
    [switch]
    $EnableKeepMeSignedIn,

    [Parameter()]
    [switch]
    $EnableEndUserPasswordChange,

    [Parameter()]
    [switch]
    $EnableWsTrust13WinTransport,

    [Parameter()]
    [switch]
    $AddPasswordExpiryClaim,

    [Parameter()]
    [switch]
    $AddAuthNMethodsClaim,

    [Parameter()]
    [switch]
    $EnableExtranetLockout,

    [Parameter()]
    [int]
    $ExtranetLockoutThreshold = 3,

    [Parameter()]
    [int]
    $ExtranetLockoutObservationWindow = 30,

    [Parameter()]
    [switch]
    $ExtranetLockoutRequirePDC,

    [Parameter()]
    [switch]
    $EnableVerboseLogging,

    [Parameter()]
    [switch]
    $CheckPatches
    
    )

Import-Module Adfs

$ExtranetLockoutRequirePDC = $false

$VerbosePreference = "Continue"

#TODO: Ensure AD FS farm behaviour level is 2016
<#if ((Get-AdfsProperties).CurrentBehaviorLevel -lt 3) {
    # The functional level is below the current level. Let's raise it
    Invoke-AdfsFarmBehaviorLevelRaise -Confirm:$false -Force
}#>

# Enable KMSI
if ($EnableKeepMeSignedIn) {
    Write-Verbose "Enabling Keep Me Signed In (KMSI)"
    Set-AdfsProperties -EnableKmsi:$true
} else {
    Write-Verbose "KMSI check is disabled"
}

# Enable end-user password change
if ($EnableEndUserPasswordChange) {
    Write-Verbose "Enabling End-User Password Change"
    Enable-AdfsEndpoint "/adfs/portal/updatepassword/" -Verbose:$false
    Set-AdfsEndpoint "/adfs/portal/updatepassword/" -Proxy:$true -Verbose:$false
} else {
    Write-Verbose "End-User Password Change check is disabled"
}

# Enable WS-Trust 1.3
if ($EnableWsTrust13WinTransport) {
    Write-Verbose "Enabling WS-Trust 1.3"
    Enable-AdfsEndpoint "/adfs/services/trust/13/windowstransport" -Verbose:$false
    Set-AdfsEndpoint "/adfs/services/trust/13/windowstransport" -Proxy:$true -Verbose:$false
} else {
    Write-Verbose "WS-Trust 1.3 check is disabled"
}

# Enable Office 365 Password Expiry Notifications
if ($AddPasswordExpiryClaim) {
    Write-Verbose "Enabling Password Expiry Claim"
    throw [System.NotImplementedException] "Password Expiry Claim not yet implemented"
} else {
    Write-Verbose "Password Expiry Claim check is disabled"
}

# Enable OFfice 365 AuthN Methods References
if ($BPs.Office365AuthNMethods) {
    Write-Verbose "Enabling AuthN Methods Reference Claim"
    throw [System.NotImplementedException] "Office 365 AuthN Methods Claim not yet implemented"
} else {
    Write-Verbose "AuthN Methods Rerference check is disabled"
}

# Enable Extranet Lockout
if ($EnableExtranetLockout) {
    Write-Verbose "Enabling Extranet Lockout"
    Set-AdfsProperties -EnableExtranetLockout:$true `
        -ExtranetLockoutThreshold $ExtranetLockoutThreshold `
        -ExtranetObservationWindow (New-TimeSpan -Minutes $ExtranetLockoutObservationWindow) `
        -ExtranetLockoutRequirePDC $ExtranetLockoutRequirePDC
} else {
    Write-Verbose "Extranet Lockout check is disabled"
}

if ($ExtendTokenCertificateLifetime) {
    Write-Verbose "Extending Token Certificate Lifetime"
    Set-AdfsProperties -CertificateDuration 1827
    #TODO: Add check here to renew the certs only if there are no relying parties configured
    Update-AdfsCertificate -CertificateType Token-Decrypting -Urgent
    Update-AdfsCertificate -CertificateType Token-Signing -Urgent
} else {
    Write-Verbose "Extended Token Certificate Lifetime check disabled"
}

# Enable verbose logging
if ($EnableVerboseLogging) {
    Write-Verbose "Enabling verbose Logging"
    Set-ADFSProperties -LogLevel Information,Errors,Verbose,Warnings,FailureAudits,SuccessAudits
    #TODO: Make this apply to all servers in the farm, not just the local server
    $null = auditpol.exe /set /subcategory:"Application Generated" /failure:enable /success:enable
} else {
    Write-Verbose "Verbose Logging check is disabled"
}

#TODO: Restart all AD FS services in the farm
Write-Verbose "Restarting AD FS"
Restart-Service AdfsSrv -Force
Write-Warning "AD FS has been restarted on this server, you must restart it on all other servers in the farm."