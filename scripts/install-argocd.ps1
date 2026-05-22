param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("test", "prod")]
    [string]$Environment,

    [string]$Region = "eu-central-1"
)

$repoRoot = Split-Path -Parent $PSScriptRoot
$clusterName = "voyager-$Environment"
$valuesFile = Join-Path $repoRoot "argocd\$Environment\argocd-values.yaml"
$rootApplication = Join-Path $repoRoot "argocd\$Environment\root-application.yaml"

Write-Host "Updating kubeconfig for $clusterName..."
aws eks update-kubeconfig --region $Region --name $clusterName
if ($LASTEXITCODE -ne 0) {
    throw "Failed to update kubeconfig for $clusterName"
}

Write-Host "Creating argocd namespace if needed..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
if ($LASTEXITCODE -ne 0) {
    throw "Failed to create/apply argocd namespace"
}

Write-Host "Adding Argo Helm repo..."
helm repo add argo https://argoproj.github.io/argo-helm 2>$null
helm repo update
if ($LASTEXITCODE -ne 0) {
    throw "Failed to update Helm repos"
}

Write-Host "Installing ArgoCD with Helm..."
helm upgrade --install argocd argo/argo-cd `
    --namespace argocd `
    --create-namespace `
    --wait `
    --timeout 10m `
    -f $valuesFile
if ($LASTEXITCODE -ne 0) {
    throw "Helm install for ArgoCD failed"
}

Write-Host "Applying root ArgoCD application..."
kubectl apply -f $rootApplication
if ($LASTEXITCODE -ne 0) {
    throw "Failed to apply root ArgoCD application"
}

Write-Host ""
Write-Host "ArgoCD bootstrap finished for $Environment."
Write-Host "Useful follow-up commands:"
Write-Host "  kubectl get pods -n argocd"
Write-Host "  kubectl get applications -n argocd"
Write-Host "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=""{.data.password}"""
