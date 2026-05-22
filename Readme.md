# Voyager

Voyager is a small full-stack sample application deployed with a GitOps-style workflow on AWS.

The repository contains:

- a Go backend
- a React frontend
- Helm charts for both applications
- ArgoCD application definitions
- Terraform for `shared`, `test`, and `prod` infrastructure
- GitLab CI pipeline configuration for build, deploy, and rollback flows

If you only want to run the app locally, you can do that with Docker in a few minutes.
If you want the full cloud setup, this README also explains the AWS path step by step (warning this may cost you real money)

## Current layout

```text
Voyager/
  argocd/
    test/
    prod/
  backend/
    helm/
    cmd/
    packages/
  frontend/
    helm/
    config/
    src/
  terraform/
    shared/
    test/
    prod/
    policies/
  scripts/
  docker-compose.yml
  .gitlab-ci.yml
```

## App deployment model

The app deployment flow is:

1. GitLab CI builds backend and frontend images.
2. Images get pushed to private ECR.
3. CI updates the Helm values image tag.
4. CI calls ArgoCD CLI.
5. ArgoCD syncs the environment from this repo.

The sample app uses:

- separate Helm chart for backend
- separate Helm chart for frontend
- same charts in all environments
- environment-specific values files only

Backend secrets are designed to come from `AWS Secrets Manager` through `External Secrets`.

## Quick Start

If you do not care about AWS yet and just want to run the project locally:

```powershell
docker compose up --build
```

Then open:

- frontend: [http://localhost:3000](http://localhost:3000)
- backend ping endpoint: [http://localhost:8080/api/ping](http://localhost:8080/api/ping)

To stop everything:

```powershell
docker compose down
```

## Setup

### Option A: Run Locally Only

This is the easiest path. You do not need AWS, Terraform, kubectl, or ArgoCD for this mode.

#### 1. Install the required tools

Install:

- Git
- Docker Desktop

That is enough for the local version.

#### 2. Clone the repository

```powershell
git clone https://gitlab.com/rannelkood3/voyager.git
cd voyager
```

#### 3. Start the application stack

```powershell
docker compose up --build
```

What this starts:

- `db`: PostgreSQL
- `backend`: Go API
- `frontend`: React app served through Nginx

#### 4. Check that it works

Frontend:

- [http://localhost:3000](http://localhost:3000)

Backend health:

- [http://localhost:8080/api/ping](http://localhost:8080/api/ping)

#### 5. Stop it

```powershell
docker compose down
```

### Option B: Full AWS / Kubernetes Setup

This is the path if you want to run the project the same way it is intended in the cloud.

This setup is longer, because it includes:

- shared AWS resources
- Kubernetes cluster
- database
- certificates
- GitOps deployment with ArgoCD
- monitoring stack

### Before you start

You need:

- an AWS account
- permission to create EKS, EC2, IAM, Route53, RDS, ACM, S3, ECR, and Secrets Manager resources
- a domain name you control
- GitLab account if you want to use the pipeline exactly as provided

#### Recommended tools to install

Install these on your machine first:

- Git
- Docker Desktop
- AWS CLI
- Terraform
- kubectl
- Helm
- PowerShell 7 or Windows PowerShell

Useful version check commands:

```powershell
git --version
docker --version
aws --version
terraform version
kubectl version --client
helm version
```

### Step 1: Configure AWS access

Sign in to AWS and create credentials for CLI access.

Then configure the AWS CLI:

```powershell
aws configure
```

Enter:

- AWS Access Key ID
- AWS Secret Access Key
- region, usually `eu-central-1`
- output format, for example `json`

Verify it works:

```powershell
aws sts get-caller-identity
```

If this command fails, stop here and fix AWS access first.

### Step 2: Clone the repository

```powershell
git clone https://gitlab.com/rannelkood3/voyager.git
cd voyager
```

### Step 3: Understand the three Terraform stacks

The project is split into:

- `terraform/shared`
  - state bucket
  - lock table
  - ECR repositories
- `terraform/test`
  - test VPC
  - test EKS
  - test database
  - test DNS zones and certificates
  - test IAM roles and logging resources
- `terraform/prod`
  - production equivalent resources

In practice, bring them up in this order:

1. `shared`
2. `test`
3. `prod`

### Step 4: Review and edit Terraform variables

The project contains environment settings such as:

- project name
- cluster name
- VPC CIDR
- subnets
- AWS region
- domain name

Before applying anything, check:

- `domain_name`
- `project_name`
- `owner` tag
- region

If you are using your own domain, replace the domain values carefully.

### Step 5: Create shared resources

Go into the shared Terraform directory:

```powershell
cd .terraform\shared
terraform init
terraform apply
```

This creates:

- S3 bucket for Terraform state
- DynamoDB lock table
- ECR repository for backend
- ECR repository for frontend

Save the outputs. They are useful later.

### Step 6: Create the test environment

```powershell
cd \terraform\test
terraform init
terraform apply
```

This creates the `test` environment, including:

- VPC
- subnets
- NAT gateway
- EKS cluster
- three node groups: `main`, `tools`, `monitoring`
- bastion instance
- managed PostgreSQL database
- Route53 public and private hosted zones
- ACM certificates
- logs bucket
- Secrets Manager secret
- IAM roles for cluster components

When the apply finishes, note the outputs such as:

- cluster name
- public certificate ARN
- private certificate ARN
- backend secret name

### Step 7: Update certificate placeholders in the Helm and ArgoCD values

From repo root:

```powershell
.\scripts\set-cert-placeholders.ps1 -Environment test -PublicCertArn "<PUBLIC_CERT_ARN>" -PrivateCertArn "<PRIVATE_CERT_ARN>"
```

Replace:

- `<PUBLIC_CERT_ARN>`
- `<PRIVATE_CERT_ARN>`

with the actual values from Terraform outputs.

### Step 8: Make sure you can reach the test EKS cluster

Update kubeconfig:

```powershell
aws eks update-kubeconfig --region eu-central-1 --name voyager-test
kubectl get nodes
```

You should see nodes from the cluster.

If `kubectl` cannot connect, check:

- your current network
- the EKS endpoint access configuration
- your public IP if the cluster allows only restricted public access

### Step 9: Install ArgoCD

```powershell
.\scripts\install-argocd.ps1 -Environment test
```

This script:

- updates kubeconfig
- creates the `argocd` namespace
- installs ArgoCD with Helm
- applies the root ArgoCD application

Check status:

```powershell
kubectl get pods -n argocd
kubectl get applications -n argocd
```

### Step 10: Push the repository before expecting ArgoCD to sync

ArgoCD reads from Git.

If the repository is not pushed, ArgoCD has nothing to deploy.

Make sure your GitLab repo is reachable and contains your latest manifests:

```powershell
git status
git add .
git commit -m "Initial setup"
git push origin main
```

### Step 11: Build and push images to ECR

You need frontend and backend images in ECR before the cluster can run them.

Log in to ECR:

```powershell
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 521495324055.dkr.ecr.eu-central-1.amazonaws.com
```

Build and push backend:

```powershell
cd .\backend
docker build -t 521495324055.dkr.ecr.eu-central-1.amazonaws.com/voyager-rannel/backend:test .
docker push 521495324055.dkr.ecr.eu-central-1.amazonaws.com/voyager-rannel/backend:test
```

Build and push frontend:

```powershell
cd .\frontend
docker build -t 521495324055.dkr.ecr.eu-central-1.amazonaws.com/voyager-rannel/frontend:test .
docker push 521495324055.dkr.ecr.eu-central-1.amazonaws.com/voyager-rannel/frontend:test
```

### Step 12: Verify the deployed workloads

Useful commands:

```powershell
kubectl get pods -A
kubectl get pods -A -o wide
kubectl get ingress -A
kubectl get applications -n argocd
```

Things to look for:

- ArgoCD pods running
- External Secrets running
- External DNS running
- Grafana / Loki / Prometheus components running
- frontend and backend pods running

### Step 13: Access ArgoCD

Port-forward:

```powershell
kubectl port-forward service/argocd-server -n argocd 8080:443
```

Open:

- [http://localhost:8080](http://localhost:8080)

Get the admin password:

```powershell
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
```

If needed, decode in PowerShell:

```powershell
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | %{ [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

### Step 14: Access Grafana

Port-forward:

```powershell
kubectl port-forward svc/voyager-monitoring-grafana -n monitoring 3000:80
```

Open:

- [http://localhost:3000](http://localhost:3000)

Get Grafana credentials:

```powershell
kubectl get secret voyager-monitoring-grafana -n monitoring -o jsonpath="{.data.admin-user}" | %{ [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
kubectl get secret voyager-monitoring-grafana -n monitoring -o jsonpath="{.data.admin-password}" | %{ [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

## Local Development Notes

The fastest day-to-day loop is still local Docker:

```powershell
docker compose up --build
```

Use the full AWS stack when you need to verify:

- Kubernetes scheduling
- ArgoCD sync
- External Secrets
- External DNS
- monitoring
- load balancers
- Route53 records

## CI/CD

The GitLab pipeline is defined in `\.gitlab-ci.yml`

It includes:

- Go tests
- Helm lint
- Docker image build and push
- ArgoCD sync for `test`
- manual deploy for `prod`
- manual rollback job for `prod`

## Known Notes

- The shared Terraform stack creates an S3 bucket and DynamoDB lock table intended for remote Terraform state, but the current environment stacks still need explicit backend configuration if you want Terraform to stop using local `.tfstate` files.
- The `test` environment is the environment most suitable for first validation.
- `prod` requires its own certificate placeholder replacement and environment-specific values before deployment.

## Useful Commands

```powershell
kubectl get pods -A
kubectl get applications -n argocd
kubectl get ingress -A
kubectl get nodes -L workload
aws sts get-caller-identity
aws ecr list-images --region eu-central-1 --repository-name voyager-rannel/backend
aws ecr list-images --region eu-central-1 --repository-name voyager-rannel/frontend
```
