param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("test", "prod")]
    [string]$Environment,

    [Parameter(Mandatory = $true)]
    [string]$PublicCertArn,

    [Parameter(Mandatory = $true)]
    [string]$PrivateCertArn
)

$repoRoot = Split-Path -Parent $PSScriptRoot

if ($Environment -eq "test") {
    $files = @(
        @{ Path = Join-Path $repoRoot "backend\helm\values-test.yaml"; Placeholder = "REPLACE_WITH_TEST_PUBLIC_CERT_ARN"; Value = $PublicCertArn },
        @{ Path = Join-Path $repoRoot "frontend\helm\values-test.yaml"; Placeholder = "REPLACE_WITH_TEST_PUBLIC_CERT_ARN"; Value = $PublicCertArn },
        @{ Path = Join-Path $repoRoot "argocd\test\applications\values.yaml"; Placeholder = "REPLACE_WITH_TEST_PRIVATE_CERT_ARN"; Value = $PrivateCertArn },
        @{ Path = Join-Path $repoRoot "argocd\test\argocd-values.yaml"; Placeholder = "REPLACE_WITH_TEST_PUBLIC_CERT_ARN"; Value = $PublicCertArn }
    )
}
else {
    $files = @(
        @{ Path = Join-Path $repoRoot "backend\helm\values-prod.yaml"; Placeholder = "REPLACE_WITH_PROD_PUBLIC_CERT_ARN"; Value = $PublicCertArn },
        @{ Path = Join-Path $repoRoot "frontend\helm\values-prod.yaml"; Placeholder = "REPLACE_WITH_PROD_PUBLIC_CERT_ARN"; Value = $PublicCertArn },
        @{ Path = Join-Path $repoRoot "argocd\prod\applications\values.yaml"; Placeholder = "REPLACE_WITH_PROD_PRIVATE_CERT_ARN"; Value = $PrivateCertArn },
        @{ Path = Join-Path $repoRoot "argocd\prod\argocd-values.yaml"; Placeholder = "REPLACE_WITH_PROD_PUBLIC_CERT_ARN"; Value = $PublicCertArn }
    )
}

foreach ($file in $files) {
    $content = Get-Content -Raw $file.Path
    $updated = $content.Replace($file.Placeholder, $file.Value)
    Set-Content -Path $file.Path -Value $updated
    Write-Host "Updated $($file.Path)"
}

Write-Host ""
Write-Host "Certificate placeholders updated for $Environment."
