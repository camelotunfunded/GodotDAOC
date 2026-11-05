param(
    [Parameter(Mandatory = $true)]
    [string]$ClientRoot
)

$ErrorActionPreference = "Stop"
$resolved = [System.IO.Path]::GetFullPath($ClientRoot)

if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
    throw "Le dossier client n'existe pas : $resolved"
}

$expected = @("game.dll", "zones")
$missing = @()
foreach ($name in $expected) {
    if (-not (Test-Path -LiteralPath (Join-Path $resolved $name))) {
        $missing += $name
    }
}
if ($missing.Count -gt 0) {
    throw "Ce dossier ne ressemble pas à un client DAoC complet. Manquant : $($missing -join ', ')"
}

$cache = Join-Path $resolved "_godot_daoc_cache"
$data = Join-Path $cache "data"
$models = Join-Path $cache "models"
New-Item -ItemType Directory -Path $data -Force | Out-Null
New-Item -ItemType Directory -Path $models -Force | Out-Null

$env:DAOC_CLIENT_ROOT = $resolved

Write-Host "Client vérifié : $resolved"
Write-Host "Cache prêt : $cache"
Write-Host "DAOC_CLIENT_ROOT est défini pour cette session PowerShell."
Write-Host "Ouvrez maintenant project.godot depuis cette même session."
Write-Host "Aucune archive DAoC n'a été modifiée."

