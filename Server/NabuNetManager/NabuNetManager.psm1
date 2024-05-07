# script variables...

$CurrentContext = @{
    Host         = $null
    Token        = $null   # access token for this current connection...
    TokenExpires = $null
    Name         = $null
}

# helper classes first...

class NabuUpdateImages {
    NabuUpdateImages($in){
        $this.ConfigImageVersion = $in.ConfigImageVersion
        $this.ConfigImageAssetId = $in.ConfigImageAsset
        $this.FirmwareImageVersion = $in.FirmwareImageVersion
        $this.FirmwareImageAssetId = $in.FirmwareImageAsset
    }
    [string]$ConfigImageVersion
    [string]$FirmwareImageVersion
    [Nullable[int]]$ConfigImageAssetId
    [Nullable[int]]$FirmwareImageAssetId
}

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

# public visible server context info
class NabuAccountInfo {
    NabuAccountInfo($in) {
        $this.Name = $in.Name
        $this.IsComplete = [bool]$in.isComplete
        $this.ContactEMail = $in.contactEMail
        $this.DisplayName = $in.displayName
        $this.HighscoreName = $in.highscoreName
        $this.EnableApiAccess = [bool]$in.enableAPIAccess
        $this.EnableDeviceConnections = [bool]$in.enableDeviceConnections
        $this.IsAdministrator = [bool]$in.isAdministrator
        $this.IsContentManager = [bool]$in.isContentManager
        $this.IsEnabled = [bool]$in.isEnabled
        $this.IsModerator = [bool]$in.isModerator
    }
    [string] $Name
    [string] $ContactEMail
    [string] $DisplayName
    [string] $HighscoreName
    [bool] $EnableApiAccess
    [bool] $EnableDeviceConnections
    [bool] $IsAdministrator
    [bool] $IsContentManager
    [bool] $IsEnabled
    [bool] $IsModerator
    [bool] $IsComplete
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
    else 
    {
        throw "Registered host $Name not found! (casing?)"
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
        Write-Verbose "Body for request: $($Body.Length) characters"
        if ($Body.Length -lt 100)
        {
            Write-Verbose " Body for request: $Body"
        }
        else
        {
            Write-Verbose " Body for request: $($Body.SubString(0,40))...$($Body.SubString($Body.Length-40))"
        }
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
        default { Write-Verbose $($tmp ?? "no result"); throw "Unkown/unexpected status code returned from remote API: $code" }
    }

} 

# actual module functions start here...

function Get-Account {
    [CmdletBinding()]
    [OutputType([NabuAccountInfo])]
    param (
        [Parameter()]
        [switch] $Full
    )
<#
.SYNOPSIS
    Gets the list of user accounts on the connected server. Requires admin or moderator permission. When the "Full" option is omitted, only the names are populated to speed up access.

.PARAMETER Full
    When provided, all properties of the returned user items are filled.

.OUTPUTS 
    NabuAccountInfo
#>

    Call-Napi -Path "accounts" -Query @{ "full" = $Full.IsPresent } | ForEach-Object { New-Object NabuAccountInfo -ArgumentList $_ }
}

function Get-UpdateImages {
    [CmdletBinding()]
    [OutputType([NabuUpdateImages])]
    param(
    )
    <#
.SYNOPSIS
Retreives the current configured update image details.

.DESCRIPTION
The NabuServer supports updates for the modem firmware and config programs. One of each can be active at any time.

.OUTPUTS
NabuUpdateImages
#>

    Call-Napi -Path "updates" | ForEach-Object { New-Object NabuUpdateImages -ArgumentList $_ }
}

function Set-FirmwareImage {
    [CmdletBinding(DefaultParameterSetName="path")]
    param(
        [Parameter(ParameterSetName="path")]
        [string]$Path,
        [Parameter(ParameterSetName="raw")]
        [byte[]]$Raw
    )
    <#
.SYNOPSIS
Updates the server's firmware boot image.

.DESCRIPTION
The NabuServer supports updates for the modem firmware and config programs. One of each can be active at any time.
This call will set the image for the firmware, based on the provided package file.

.OUTPUTS
NabuUpdateImages
#>
    [string]$content = ""
    if ($PSCmdlet.ParameterSetName -eq "path")
    {
        $content = [System.Convert]::ToBase64String((Get-Content -AsByteStream -Path $Path))
    }
    else {
        $content = [System.Convert]::ToBase64String($Raw)
    }
    [int]$assetId = Call-Napi -Path "asset/deploy" -Method "POST" -Body $content
    Call-Napi -Path "updates/set" -Method "PUT" -Query @{ newFirmwareAsset = $assetId } | ForEach-Object { New-Object NabuUpdateImages -ArgumentList $_ }
}

function Set-ConfigImage {
    [CmdletBinding(DefaultParameterSetName="path")]
    [OutputType([NabuUpdateImages])]
    param(
        [Parameter(ParameterSetName="path")]
        [string]$Path,
        [Parameter(ParameterSetName="raw")]
        [byte[]]$Raw
    )
    <#
.SYNOPSIS
Updates the server's config program image.

.DESCRIPTION
The NabuServer supports updates for the modem firmware and config programs. One of each can be active at any time.
This call will set the image for the config program, based on the provided package file.

.OUTPUTS
NabuUpdateImages
#>
    [string]$content = ""
    if ($PSCmdlet.ParameterSetName -eq "path")
    {
        $content = [System.Convert]::ToBase64String((Get-Content -AsByteStream -Path $Path))
    }
    else {
        $content = [System.Convert]::ToBase64String($Raw)
    }
    [int]$assetId = Call-Napi -Path "asset/deploy" -Method "POST" -Body $content
    Call-Napi -Path "updates/set" -Method "PUT" -Query @{ newConfigAsset = $assetId } | ForEach-Object { New-Object NabuUpdateImages -ArgumentList $_ }
}

function Clear-FirmwareImage {
    [CmdletBinding()]
    [OutputType([NabuUpdateImages])]
    param(
    )
    <#
.SYNOPSIS
Clears the server's firmware boot image.

.DESCRIPTION
The NabuServer supports updates for the modem firmware and config programs. One of each can be active at any time.
This call will set the image for the firmware, based on the provided package file.

.OUTPUTS
NabuUpdateImages
#>
    Call-Napi -Path "updates/set" -Method "PUT" -Query @{ newFirmwareAsset = 0 } | ForEach-Object { New-Object NabuUpdateImages -ArgumentList $_ }
}


function Clear-ConfigImage {
    [CmdletBinding()]
    [OutputType([NabuUpdateImages])]
    param(
    )
    <#
.SYNOPSIS
Clears the server's config program image.

.DESCRIPTION
The NabuServer supports updates for the modem firmware and config programs. One of each can be active at any time.
This call will set the image for the config program, based on the provided package file.

.OUTPUTS
NabuUpdateImages
#>
    Call-Napi -Path "updates/set" -Method "PUT" -Query @{ newConfigAsset = 0 } | ForEach-Object { New-Object NabuUpdateImages -ArgumentList $_ }
}

function Build-ConfigAsset
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidatePattern("^[a-zA-Z0-9_\-\.][a-zA-Z0-9_\-\.\s]{1,30}[a-zA-Z0-9_\-\.]$")][string]$Title,
        [Parameter(Mandatory=$true)][string]$Author,
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)][string]$SourceImage,
        [Parameter(Mandatory=$true)][string]$OutputPath
    )
    <#
.SYNOPSIS
Creates a NabuNet "asset" - i.e. a ZIP file with a manifest definition for uploading as a binary "item".

.DESCRIPTION
Binaries in NabuNet are made up of a set of actual files, depending on use. They share a common set of base properties in a
definitin file, called a "manifest"; this cmdlet will create a proper asset for deployment. Note, that there are helper functions
around that simplify well known asset creation with proper parameters!

.OUTPUTS
#>

    [string]$tmp = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([Guid]::NewGuid().ToString("n"))

    Write-Verbose "Temp folder: $tmp"
    $file = $null

    New-Item -Path $tmp -ItemType Directory -ErrorAction Stop | Out-Null
    try {

        $img = Join-Path -Path $tmp -ChildPath "nabuboot.img"

        Copy-Item -Path $SourceImage -Destination $img

        Write-Verbose " Image: $img"

        $buf = new-object byte[] 33
        
        $file = [System.IO.File]::OpenRead($img)
        $ofs = $file.ReadByte();
        $ofs = $ofs + $file.ReadByte() * 256
        $ofs -= 0x140D

        $file.Seek($ofs, "Begin") | Out-Null

        $len = $file.Read($buf, 0, 32)

        while ($len -gt 0 -and $buf[$len] -eq 0)
        {
            $len--
        }
        if ($buf[$len] -ne 0)
        {
            $len++
        }

        Write-Verbose "Read $len bytes from $ofs"

        $str = [System.Text.Encoding]::ASCII.GetString($buf, 0, $len).Trim()

        $file.Dispose()

        Write-Verbose "Read version: $str"

        Build-Asset -Title $Title -Version $str -Author $Author -Path $img -TempFolder $tmp -Type Config -OutputPath $OutputPath
    }
    finally  {
        Remove-Item -Path $tmp -Recurse -Force
        if ($file)
        {
            $file.Dispose();
        }
    }
}
function Build-FirmwareAsset
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidatePattern("^[a-zA-Z0-9_\-\.][a-zA-Z0-9_\-\.\s]{1,30}[a-zA-Z0-9_\-\.]$")][string]$Title,
        [Parameter(Mandatory=$true)][ValidatePattern("^\d{1,3}\.\d{1,3}(\.\d{1,3})?(\-[a-zA-Z]{1,10})?$")] [string]$Version,
        [Parameter(Mandatory=$true)][string]$Author,
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)][string]$SourceImage,
        [Parameter(Mandatory=$true)][string]$OutputPath
    )
    <#
.SYNOPSIS
Creates a NabuNet "asset" - i.e. a ZIP file with a manifest definition for uploading as a binary "item".

.DESCRIPTION
Binaries in NabuNet are made up of a set of actual files, depending on use. They share a common set of base properties in a
definitin file, called a "manifest"; this cmdlet will create a proper asset for deployment. Note, that there are helper functions
around that simplify well known asset creation with proper parameters!

.OUTPUTS
#>

    [string]$tmp = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([Guid]::NewGuid().ToString("n"))

    Write-Verbose "Temp folder: $tmp"

    New-Item -Path $tmp -ItemType Directory -ErrorAction Stop | Out-Null
    try {

        $img = Join-Path -Path $tmp -ChildPath "nabufirm.img"

        Copy-Item -Path $SourceImage -Destination $img

        Write-Verbose " Image: $img"

        Build-Asset -Title $Title -Version $Version -Author $Author -Path $img -TempFolder $tmp -BigBlob -Type Firmware -OutputPath $OutputPath
    }
    finally  {
        Remove-Item -Path $tmp -Recurse -Force
    }

}

function Build-Asset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidatePattern("^[a-zA-Z0-9_\-\.][a-zA-Z0-9_\-\.\s]{1,30}[a-zA-Z0-9_\-\.]$")][string]$Title,
        [Parameter(Mandatory=$true)][ValidatePattern("^\d{1,3}\.\d{1,3}(\.\d{1,3})?(\-[a-zA-Z]{1,10})?$")] [string]$Version,
        [Parameter(Mandatory=$true)][string]$Author,
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)][ValidateCount(1,255)] [string[]]$Path,
        [Parameter(Mandatory=$true)][string]$OutputPath,
        [ValidateSet("ResourceOnly","Kernel","Program","Firmware","Config")][string]$Type = "ResourceOnly",
        [string]$KernelType = "NabuNet",
        [switch]$BigBlob,
        [string]$TempFolder = $null
    )
    <#
.SYNOPSIS
Creates a NabuNet "asset" - i.e. a ZIP file with a manifest definition for uploading as a binary "item".

.DESCRIPTION
Binaries in NabuNet are made up of a set of actual files, depending on use. They share a common set of base properties in a
definitin file, called a "manifest"; this cmdlet will create a proper asset for deployment. Note, that there are helper functions
around that simplify well known asset creation with proper parameters!

.OUTPUTS
#>

    Write-Verbose "Build asset.."

    [string]$tmp = $null
    if ($TempFolder -eq $null)
    {
        $tmp = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([Guid]::NewGuid().ToString("n"))
        New-Item -Path $tmp -ItemType Directory | Out-Null
        $TempFolder = $tmp
    }
    
    try {

        [string]$mani = Join-Path -Path $TempFolder -ChildPath "manifest.json"
        
        $list = @(Get-Item -Path $Path -ErrorAction Stop)

        Write-Verbose "Found $($list.Length) files."

        [bool]$hadError = $false

        [int]$limit = 0x10000
        if ($BigBlob.IsPresent)
        {
            $limit = 4mb
        }
        $itemErrors = @($list | Where-Object -Property Length -gt $limit)
        $itemErrors | ForEach-Object { Write-Error "Item $_ is too large! Maximum of $limit!" }
        $hadError = $hadError -or [bool]$itemErrors

        Write-Verbose "Found $($itemErrors.Length) files with size limit escalation."

        $itemErrors = @($list | Where-Object -Property Name -NotMatch "^[a-zA-Z0-9_\-]{1,8}(\.[a-zA-Z0-9_\-]{0,3})?$")
        $itemErrors | ForEach-Object { Write-Error "Item $_ has an invalid filename. Must meet 8.3 specs and only contain alphanumeric characters." }
        $hadError = $hadError -or [bool]$itemErrors

        Write-Verbose "Found $($itemErrors.Length) files with file name problems."

        $itemErrors = @($list | Where-Object { $_ -isnot [System.IO.FileInfo]} )
        $itemErrors | ForEach-Object { Write-Error "Item $_ is not a file!" }
        $hadError = $hadError -or [bool]$itemErrors

        Write-Verbose "Found $($itemErrors.Length) items which aren't a file!"

        if ($hadError)
        {
            throw "Cannot continue with file errors!"
        }

        @{title = $Title; version = $Version; author = $Author; type = $Type.ToLower(); kerneltype = $KernelType; assets = @($list | Select-Object -ExpandProperty Name)} | ConvertTo-Json | Out-File -FilePath $mani

        $list = @($list | Select-Object -ExpandProperty FullName)

        $list += $mani

        Write-Verbose "Attaching $($list.Length) files."

        Compress-Archive -DestinationPath $OutputPath -Path $list -CompressionLevel Optimal -Force
        
    }
    finally {
        if ($tmp)
        {
            Remove-Item -Path $tmp -Recurse -Force
        }
    }
}


function Get-ServerAnnouncement {
    [CmdletBinding()]
    [OutputType([NabuArticleBase])]
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
    [OutputType([NabuArticleBase])]
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
    [OutputType([NabuHostInfo])]
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
    [OutputType([NabuHostInfo])]
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

.OUTPUTS
    NabuTemplateInfo

#>
    [CmdletBinding()]
    [OutputType([NabuTemplateInfo])]
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
    Get-MailTemplate, Set-MailTemplate, Approve-Account, Get-UpdateImages, `
    Set-FirmwareImage, Set-ConfigImage, Clear-FirmwareImage, Clear-ConfigImage, `
    Build-Asset, Build-FirmwareAsset, Build-ConfigAsset
