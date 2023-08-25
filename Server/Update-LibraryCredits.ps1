#!/bin/pwsh
[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $ProjectFolder = "."
)

$credits = @{}
$dirty = $false

function Update-Library {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Source,
        [Parameter()]
        [string]
        $Name,
        [Parameter()]
        [string]
        $Version = $null,
        [Parameter()]
        [string]
        $Url = $null
    )

    [string]$key = "$Source-$Name"
    if ($credits.ContainsKey($key)) {
        $existing = $credits[$key]
        if ($Version -ne $null -and $existing.Version -ne $Version) {
            $script:dirty = $true
            $existing.Version = $Version
        }
        if ($Url -ne $null -and $existing.Url -ne $Url) {
            $script:dirty = $true
            $existing.Url = $Url
        }
    }
    else {
        $script:dirty = $true
        $credits[$key] = @{ Name = $Name; Version = $Version; Url = $Url; Comment = "" }
    }
}

if (!(Test-Path -PathType Container -Path $ProjectFolder)) {
    throw "Folder $ProjectFolder doesn't exist."
}

$ProjectFile = @(Get-ChildItem -Path (Join-Path -Path $ProjectFolder -ChildPath "*.csproj"))

if ($ProjectFile.Length -ne 1) {
    throw "Folder $ProjectFolder doesn't have a project file!"
}

$outputfile = Join-Path -Path $ProjectFolder -ChildPath "library-credits.json"

if (Test-Path -PathType Leaf -Path $outputfile) {
    # we need a hashtable, not a custom object, so convert it back...
    (Get-Content -Path $outputfile | ConvertFrom-Json).psobject.properties | ForEach-Object { $credits[$_.Name] = $_.Value }
}

# read all the libarary references from the project file...
# ...and libman.json

$project = [xml](Get-Content -Path ($ProjectFile[0].FullName))

foreach ($item in $project.SelectNodes("//PackageReference")) {
    $name = $item.Include
    $version = $item.Version
    $url = "https://www.nuget.org/packages/$name"
    Write-Verbose "Found package reference: $name, $version"
    Update-Library -Source nuget -Name $name -Version $version -Url $url
}

$libmanFile = Join-Path -Path $ProjectFolder -ChildPath "libman.json"
if (Test-Path -Path $libmanFile) {
    $libs = Get-Content -Path $libmanFile | ConvertFrom-Json
    $defProvider = $libs.defaultProvider
    foreach ($item in $libs.libraries) {
        $lib = $item.library -split "@"
        $name = $lib[0]
        $version = $lib[1]
        Write-Verbose "Found library reference: $name, $version"
        $source = $item.provider ?? $defProvider
        switch ($source) {
            "cdnjs" { $url = "https://cdnjs.com/libraries/$name" }
            default { $url = $null }
        }
        Update-Library -Source libman -Name $name -Version $version -Url $url
    }
}

if ($dirty) {
    Set-Content -Path $outputfile -Value ($credits | ConvertTo-Json)
}
