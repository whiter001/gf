[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$outputName = 'gf.exe'
$publicDir = 'D:\public'
$linkPath = Join-Path $publicDir $outputName

$vCommand = Get-Command v.exe -ErrorAction SilentlyContinue
if ($null -ne $vCommand) {
    $vPath = if ($vCommand.Source) { $vCommand.Source } else { $vCommand.Path }
} elseif (Test-Path -LiteralPath 'D:\public\v.exe' -PathType Leaf) {
    $vPath = 'D:\public\v.exe'
} else {
    throw 'V compiler not found in PATH or D:\public\v.exe.'
}

Push-Location $repoRoot
try {
    & $vPath -o $outputName src
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}

$outputPath = Join-Path $repoRoot $outputName
if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
    throw "Build completed without producing $outputPath."
}

New-Item -ItemType Directory -Force -Path $publicDir | Out-Null
$existingLink = Get-Item -LiteralPath $linkPath -Force -ErrorAction SilentlyContinue
if ($null -ne $existingLink) {
    $isSymbolicLink = ($existingLink.PSObject.Properties.Name -contains 'LinkType') -and
        ($existingLink.LinkType -eq 'SymbolicLink')
    if (-not $isSymbolicLink) {
        throw "$linkPath already exists and is not a symbolic link; refusing to replace it."
    }
    Remove-Item -LiteralPath $linkPath -Force
}

New-Item -ItemType SymbolicLink -Path $linkPath -Target $outputPath | Out-Null
Write-Host "Built $outputPath"
Write-Host "Linked $linkPath -> $outputPath"
