# script variables...

$CurrentContext = @{
    Host         = $null
    Token        = $null   # access token for this current connection...
    TokenExpires = $null
    Name         = $null
}

# helper classes first...

class NabuArticleBase {
    NabuArticleBase($in) {
        $this.Title = $in.title
        $this.Article = $in.article
        $this.Created = [DateTime]::Parse($in.created)
        $this.ReferenceDate = $in.referenceDate
    }

    [string]$Title
    [string]$Article
    [DateTime]$Created
    [Nullable[DateTime]]$ReferenceDate
}

class NabuHost {
    NabuHost($name) {
        $this.Name = $name
    }
    NabuHost($name, $serialized) {
        $this.Name = $name
        $this.RemoteBaseUri = $serialized.RemoteBaseUri
        $this.Registered = $serialized.Registered
        $this.LastContacted = $serialized.LastContacted
        $this.Token = $serialized.Token
        $this.RemoteName = $serialized.RemoteName
        $this.RemoteTagline = $serialized.RemoteTagline
    }

    [string] $Name
    [string] $RemoteBaseUri
    [datetime] $Registered
    [datetime] $LastContacted
    [string] $Token
    [string] $RemoteName
    [string] $RemoteTagline
}

# public visible server context info
class NabuHostInfo {
    NabuHostInfo($in, $name = $null) {
        $this.Name = $name ?? $in.Name
        $this.Uri = $in.RemoteBaseUri
        $this.LastContacted = $in.LastContacted
        $this.Registered = $in.Registered
        $this.HasToken = [bool]$in.Token
        $this.RemoteName = $in.RemoteName
        $this.RemoteTagline = $in.RemoteTagline
    }
    [string] $Name
    [string] $Uri
    [string] $RemoteTagline
    [string] $RemoteName
    [DateTime] $LastContacted
    [DateTime] $Registered
    [bool] $HasToken
}

class NabuTemplateInfo {
    NabuTemplateInfo($in, $name = $null) {
        $this.Id = $name ?? $in.Id
        $this.Subject = $in.Subject
        $this.Body = $in.Body
    }
    [ValidatePattern("^[a-zA-Z0-9]+$", ErrorMessage = "Only letters and digits allowed!")]
    [string] $Id
    [ValidatePattern("^[^\n\r]+$", ErrorMessage = "May not contain newlines!")]
    [string] $Subject
    [string] $Body
}

# helper functions next...

function Save-RegisteredHost {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Name,
        [Parameter()]
        [NabuHost]$Data
    )

    $path = Join-Path -Path "~" -ChildPath ".nabunet"

    if (!(Test-Path -Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
        # $data = Import-PowerShellDataFile -Path $path
        # New-Object NabuHost -ArgumentList $data
    }
    $path = Join-Path -Path $path -ChildPath "$Name.xml"
    $Data | Export-Clixml -Path $path
}

function Load-RegisteredHost {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Name
    )
    $path = Join-Path -Path "~" -ChildPath ".nabunet"
    $path = Join-Path -Path $path -ChildPath "$Name.xml"
    if (Test-Path -Path $path) {
        Import-Clixml -Path $path | ForEach-Object { New-Object NabuHost -ArgumentList $Name, $_ } # | Where-Object { $_ -is [NabuHost] }
        # $data = Import-PowerShellDataFile -Path $path
        # New-Object NabuHost -ArgumentList $data
    }
}

function Get-AllRegisteredHost {
    [CmdletBinding()]
    param (
    )
    $path = Join-Path -Path "~" -ChildPath ".nabunet"
    if (Test-Path -Path $path) {
        Get-ChildItem -Path (Join-Path -Path $path -ChildPath "*.xml")
    }
}


function Call-Napi {
    [CmdletBinding(PositionalBinding = $false)]
    param (
        [Parameter()]
        [NabuHost]$Connection = $null,
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter()]
        [string]$Version = "v1",
        [Parameter()]
        [string]$Method = "GET",
        [Parameter()]
        [Object]$Body = $null,
        [Parameter()]
        [hashtable]$Query = $null
    )
    $Token = $null
    if (!$Connection) {
        $Connection = $script:CurrentContext.Host
        $Token = $script:CurrentContext.Token
        $Expires = $script:CurrentContext.TokenExpires
        if ($null -eq $Token -or ($Expires -lt [DateTime]::UtcNow)) {
            # token is missing or expired...
            if ($null -ne $Connection.Token) {
                Write-Verbose "Access token needed, requesting..."
                $tmp = Call-Napi -Connection $Connection -Version $Version -Path "login" -Body @{ token = $Connection.Token } -Method "POST"
                if ($tmp.token) {
                    $script:CurrentContext.Token = $tmp.token
                    $Token = $tmp.token
                    $script:CurrentContext.TokenExpires = [datetime]::Parse($tmp.validUntil).AddSeconds(-10)    # safety margin...
                    $Expires = $script:CurrentContext.TokenExpires
                    $tmp = $null
                }
                else {
                    $script:CurrentContext.Token = $null
                    $script:CurrentContext.TokenExpires = $null
                    throw "Login call didn't yield a valid token..."
                }
            }
            else {
                Write-Verbose "Access token needed, but no token provided, can only call anonymously!"
            }
        }
        else {
            Write-Verbose "Access token present and valid."
        }
    }
    if (!$Connection) {
        throw "Session is not connected! Use Connect-NabuNetHost first!"
    }
    $Uri = "$($Connection.RemoteBaseUri)/$Version/$Path"
    if ($Query) {
        $sep = "?"
        foreach ($qname in $Query.Keys) {
            $Uri += "$sep$qname=$([Uri]::EscapeDataString($Query[$qname]))"
            $sep = "&"
        }
    }
    Write-Verbose "Call: URI=$Uri"
    $hdr = @{}
    if ($Token) {
        $hdr["Authorization"] = "Bearer $Token"
        Write-Verbose "Authentication set"
    }
    if ($Body) {
        $Body = $Body | ConvertTo-Json
        $tmp = Invoke-RestMethod -Method $Method -Uri $Uri -UserAgent "NabuNetPS/1" -Headers $hdr -Body $Body -ContentType "application/json" -StatusCodeVariable code -SkipHttpErrorCheck
    }
    else {
        $tmp = Invoke-RestMethod -Method $Method -Uri $Uri -UserAgent "NabuNetPS/1" -Headers $hdr -StatusCodeVariable code -SkipHttpErrorCheck
    }
    switch ($code) {
        200 { $tmp }    # normal result.
        204 {}  # expected sometimes: no content.
        302 { throw "Access denied!" }  # 302 redirect to login page; should look into that and make the server return a better error, but it's OK for now.
        404 { Write-Error "Item not found" }
        default { throw "Unkown/unexpected status code returned from remote API: $code" }
    }

} 

# actual module functions start here...

function Get-Account {
    [CmdletBinding()]
    param (
    )
    Call-Napi -Path "accounts"# | ForEach-Object { @{ UserName = $_ } }
}

function Get-ServerAnnouncement {
    [CmdletBinding()]
    param (
        [switch]$Raw
    )
    <#
.SYNOPSIS
Retreives the current server announcement message (maintenance notice)

.DESCRIPTION
The Nabu Server has a single, central special article for server maintenance info. If set, it
will be shown prominently on the landing page and some other key pages as a headline with a link 
to the full article.

.OUTPUTS
NabuArticleBase

.PARAMETER Raw
If provided, the returned article info from the server will be the raw (markdown) text, if not a plain text rendering is provided.
#>
    Call-Napi -Path "announcement" -Query @{ raw = $Raw.IsPresent } | ForEach-Object { New-Object NabuArticleBase -ArgumentList $_ }
}

function Clear-ServerAnnouncement {
    <#
.SYNOPSIS
Clears (removes) a server announcement message (maintenance notice)

.DESCRIPTION
The Nabu Server has a single, central special article for server maintenance info. If set, it
will be shown prominently on the landing page and some other key pages as a headline with a link 
to the full article.

.OUTPUTS
nothing

#>
    [CmdletBinding(PositionalBinding = $false, ConfirmImpact = "Medium", SupportsShouldProcess = $true)]
    param ()
    if ($PSCmdlet.ShouldProcess($CurrentContext.Host.Name, "Remove announcement message on server")) {
        Write-Verbose "Removing server announcement message."
        Call-Napi -Path "announcement" -Method "DELETE" | Out-Null
    }
}

function Set-ServerAnnouncement {
    <#
.SYNOPSIS
Sets (updates or creates) a server announcement message (maintenance notice)

.DESCRIPTION
The Nabu Server has a single, central special article for server maintenance info. If set, it
will be shown prominently on the landing page and some other key pages as a headline with a link 
to the full article.

.OUTPUTS
NabuArticleBase

.PARAMETER Title
The title for the article.

.PARAMETER Article
The body (full text, markdown!) for the article.

.PARAMETER ReferenceDate
If provided, indicates a date (and time) for the operation in question. The server will include that info
on the details page, complete with absolute and relative server time info.

.PARAMETER Raw
If provided, the returned article info from the server will be the raw (markdown) text, if not a plain text rendering is provided.
#>
    [CmdletBinding(PositionalBinding = $false, ConfirmImpact = "Medium", SupportsShouldProcess = $true)]
    param (
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Title,
        [Parameter(Position = 1, Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Article,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Nullable[datetime]]$ReferenceDate = $null,
        [switch]$Raw
    )
    process {
        if ($PSCmdlet.ShouldProcess($CurrentContext.Host.Name, "Update announcement message on server, $Title")) {
            Write-Verbose "Setting server announcement message to '$Title', $($Article.Length) characters article..."
            Call-Napi -Path "announcement" -Method "POST" -Query @{ raw = $Raw.IsPresent } -Body @{ title = $Title; article = $Article; referenceDate = $ReferenceDate } | ForEach-Object { New-Object NabuArticleBase -ArgumentList $_ }
        }
    }
}

function Register-Host {
    <#
.SYNOPSIS 
Creates a new server registration for the current user.

.DESCRIPTION
The server configuration is stored in the user home folder, subfolder ".nabunet" 
as a configuration file with the server name as a root name, psd1 as an extension.

If a token is provided, it will be used for authentication, if not, the token 
needs to be provided by calling the Update-NabuNetHost cmdlet.

.PARAMETER Name
The local name to use for the server. Defaults to the host name if not specified.

.PARAMETER Host
The host name of the remote server.

.PARAMETER Token
The security token (API Token) as for the user.

.PARAMETER Port
The TCP port number - defaults to 443 for HTTPS.

.PARAMETER Path
The path of the NAPI interface, defaults to the "/napi" folder.
#>
    [CmdletBinding(PositionalBinding = $false)]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Host,
        [Parameter(Position = 1)]
        [string]$Name = $null,
        [string]$Token = $null,
        [ValidateRange(1, 65535)]
        [int]$Port = 443,
        [ValidatePattern("^(/[a-zA-Z0-9\-\.\_]+)+$", ErrorMessage = "Not a valid path for NAPI. Must start with a / and only contain letters, numbers, dashes and dots.")]
        [string]$Path = "/napi"
    )
    if ($null -eq $Name) {
        $Name = $Host
    }

    $h = Load-RegisteredHost -Name $Name
    if ($null -ne $h) {
        throw "The name $Name is already registered! Remove it first or use Update-NabuNetHost"
    }

    $h = New-Object NabuHost -ArgumentList $Name
    $h.RemoteBaseUri = "https://$($Host):$Port$Path"
    $h.Registered = [DateTime]::UtcNow
    $h.LastContacted = [DateTime]::MinValue
    $h.Token = $Token
    $h.RemoteName = $null
    $h.RemoteTagline = $null
    #-ArgumentList @{Host = $Host; Port = $port; Path = $Path; Registered = [DateTime]::UtcNow; LastContacted = [DateTime]::MinValue; RemoteName = $null; RemoteTagline = $null }

    Save-RegisteredHost -Name $Name -Data $h
}

function Connect-Host {
    <#
.SYNOPSIS
Connect the current powershell sessino to a server.

.DESCRIPTION
You can either save a connection with a name (see Register-NabuNetHost) and use that name for easy connectivity, or specify all required parameters here for a dynamic, not saved connection.

.EXAMPLE
Connect-NabuNetHost -Name testserver

Connects to the previously registered server (and token!) called "testserver".

.LINK 
Connect-NabuNetHost

.PARAMETER Name
The name of a registered server.

.PARAMETER Host
The host name of the remote server.

.PARAMETER Token
The security token (API Token) as for the user.

.PARAMETER Port
The TCP port number - defaults to 443 for HTTPS.

.PARAMETER Path
The path of the NAPI interface, defaults to the "/napi" folder.

#>
    [CmdletBinding(PositionalBinding = $false)]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Temporary")]
        [string]$Host,
        [Parameter(Position = 1, ParameterSetName = "Temporary")]
        [string]$Token = $null,
        [Parameter(ParameterSetName = "Temporary")]
        [ValidateRange(1, 65535)]
        [int]$Port = 443,
        [Parameter(ParameterSetName = "Temporary")]
        [ValidatePattern("^(/[a-zA-Z0-9\-\.\_]+)+$", ErrorMessage = "Not a valid path for NAPI. Must start with a / and only contain letters, numbers, dashes and dots.")]
        [string]$Path = "/napi",
        [Parameter(ParameterSetName = "Named", Mandatory = $true)]
        [string]$Name
    )

    if ($PSCmdlet.ParameterSetName -eq "Named") {
        # call by registered name...
        $hi = Load-RegisteredHost -Name $Name
    }
    else {
        # call by temp parameters...
        $hi = New-Object NabuHost -ArgumentList "<none>"
        $hi.RemoteBaseUri = "https://$($Host):$Port$Path"
        $hi.Registered = [DateTime]::UtcNow
        $hi.LastContacted = [DateTime]::MinValue
        $hi.Token = $Token
        $hi.RemoteName = $null
        $hi.RemoteTagline = $null
    }

    Write-Verbose "Connecting to $($hi.RemoteBaseUri)..."

    $result = Call-Napi -Connection $hi -Path "info"

    if ($result) {
        $hi.LastContacted = [DateTime]::UtcNow
        $hi.RemoteName = $result.name
        $hi.RemoteTagline = $result.tagLine

        $script:CurrentContext.Host = $hi
        $script:CurrentContext.Token = $null
        $script:CurrentContext.TokenExpires = $null
        if ($PSCmdlet.ParameterSetName -eq "Named") {
            # update saved info with most recent data...
            Save-RegisteredHost -Name $Name -Data $hi
        }
        New-Object NabuHostInfo -ArgumentList $CurrentContext.Host, $CurrentContext.Name
    }
    else {
        throw "Remote system didn't return a valid info object!"
    }
}

function Get-Host {
    <#
.SYNOPSIS
Lists the current connected Nabu server or a list of all registered servers for the current user.

.PARAMETER List
If specified, the registered servers will be listed. If not, the currently connected one will be shown.

.OUTPUTS
NabuHostInfo
#>
    [CmdletBinding(PositionalBinding = $false)]
    param (
        [switch]$List
    )
    if ($List.IsPresent) {
        #Get-AllRegisteredHost | ForEach-Object { Import-PowerShellDataFile -Path $_.FullName }
        Get-AllRegisteredHost | ForEach-Object { New-Object NabuHostInfo -ArgumentList (Import-Clixml -Path $_.FullName), $_.Name.Replace(".xml", "") }  #| Where-Object { $_ -is [NabuHost] }
    }
    else {
        if ($CurrentContext.Host) {
            New-Object NabuHostInfo -ArgumentList $CurrentContext.Host, $CurrentContext.Name
        }
    }
}

function Get-MailTemplate {
    <#
.SYNOPSIS
Retreives an e-mail template from the NabuNet server.

.DESCRIPTION
Asks the server for the subject/body of the e-mail template. Needs site admin privileges.

.PARAMETER Id
The ID (key) of the mail template.

#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidatePattern("^[a-zA-Z0-9-]+$", ErrorMessage = "Only digits and letters allowed!")]
        [string]$Id
    )

    Call-Napi -Path "template/$id" | ForEach-Object { New-Object NabuTemplateInfo -ArgumentList $_, $id }
   
}

function Set-MailTemplate {
    <#
.SYNOPSIS
Updated an e-mail template on the NabuNet server.

.DESCRIPTION
Sends the new subject/body of the e-mail template to the server. Needs site admin privileges.

.PARAMETER Id
The ID (key) of the mail template.

.PARAMETER Subject
The subject line for the e-mail. Can include handlebars.net placeholders according to the template definition.

.PARAMETER Body
The body of the e-mail. Can include handlebars.net placeholders and should be HTML formatted.
#>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $true)]
        [ValidatePattern("^[a-zA-Z0-9-]+$", ErrorMessage = "Only digits and letters allowed!")]
        [string]$Id,
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $true)]
        [ValidateLength(1, 1024)]
        [ValidatePattern("^[^\n\r]+$", ErrorMessage = "No newlines allowed!")]
        [string]$Subject,
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $true)]
        [string]$Body
    )
    process {
        if ($PSCmdlet.ShouldProcess("$Id", "Updating mail template, new subject=$Subject, body=$($body.Length) characters.")) {
            Call-Napi -Path "template/$id" -Method "POST" -Body @{ Subject = $Subject; Body = $Body }
        }
    }
  
}

# approveaccount/{userName}

function Approve-Account {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
    param (
        [Parameter()]
        [ValidateLength(1, 32)]
        [ValidatePattern("^[a-zA-Z0-9-]+$", ErrorMessage = "Only digits and letters allowed!")]
        [string]
        $Name
    )
    if ( $PSCmdlet.ShouldProcess($Name, "Confirm user account")) {
        Call-Napi -Path "approveaccount/$Name" -Method "PUT"
    }
}


Export-ModuleMember -Function Get-Host, Get-Account, Get-ServerAnnouncement, `
    Clear-ServerAnnouncement, Set-ServerAnnouncement, Connect-Host, Register-Host, `
    Get-MailTemplate, Set-MailTemplate, Approve-Account
