param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$Publisher = 'SignPath Foundation'
)
$ErrorActionPreference = 'Stop'
$signature = Get-AuthenticodeSignature -LiteralPath $Path
if ($signature.Status -ne 'Valid' -or $signature.SignatureType -ne 'Authenticode') {
    throw "Invalid embedded Authenticode signature: $Path ($($signature.Status))"
}
if (-not $signature.TimeStamperCertificate) { throw "Missing trusted timestamp: $Path" }
$actual = $signature.SignerCertificate.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
if ($actual -ne $Publisher) { throw "Unexpected publisher: $actual" }
Write-Output "Verified Authenticode signature and timestamp: $Path"
