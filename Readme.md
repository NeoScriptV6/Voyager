# Voyager

Voyager is a full-stack, cloud-native sample platform demonstrating a GitOps delivery pipeline on AWS.

It showcases how a modern application can be built, deployed, and
operated using Kubernetes, Infrastructure as Code, and automated CI/CD.

## Key Highlights

Voyager demonstrates:

- Full-stack system (Go backend + React frontend)
- Kubernetes-based deployment (AWS EKS)
- GitOps workflow using ArgoCD
- Infrastructure as Code with Terraform
- CI/CD pipelines with GitLab
- Secure secret management via AWS Secrets Manager + External Secrets
- Production-style observability stack (Prometheus, Grafana, Loki)
- Multi-environment setup (shared / test / prod)

## Architecture Overview

Voyager is designed around a GitOps-driven deployment model:

1. GitLab CI builds backend and frontend Docker images
2. Images are pushed to AWS ECR
3. CI updates Helm chart image versions
4. ArgoCD detects changes and syncs Kubernetes deployments
5. Kubernetes deploys workloads into AWS EKS clusters

Core principles:

- Declarative infrastructure (Terraform + Helm)
- Environment parity (test/prod separation)
- Git as single source of truth
- Immutable deployments via container images
- Cloud-native service design

## Tech Stack

### Backend

- Go (REST API)
- Docker
- PostgreSQL

### Frontend

- React
- Nginx-based container deployment

### Infrastructure

- AWS (EKS, EC2, RDS, S3, ECR, Route53, ACM, IAM)
- Kubernetes
- Terraform
- Helm

### DevOps / Platform

- GitLab CI/CD
- ArgoCD (GitOps)
- External Secrets Operator
- External DNS
- Prometheus + Grafana + Loki

## Repository Structure

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

## Deployment Model

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

## Environments

The system supports three environments:

- shared → global AWS resources (ECR, state backend, locking)
- test → full staging environment
- prod → production-grade environment (very similar to test, but with high resource values)

Each environment includes:

- Dedicated VPC
- EKS cluster
- RDS PostgreSQL database
- IAM roles and security boundaries
- DNS and TLS configuration

## Local Development

Run the full stack locally with Docker:

docker compose up --build

Access: - Frontend: <http://localhost:3000> - Backend:
<http://localhost:8080/api/ping>

Stop: docker compose down

Local mode includes: - PostgreSQL - Backend API (Go) - Frontend (React +
Nginx)

## Cloud Deployment (AWS)

The full deployment includes:

- AWS EKS Kubernetes cluster
- Terraform-managed infrastructure
- ArgoCD GitOps deployment
- CI/CD pipeline with automated builds
- Secure secret injection via AWS Secrets Manager
- Production observability stack

Note: Running the full AWS stack may incur infrastructure costs.

## Security & Secrets

- Secrets stored in AWS Secrets Manager
- Kubernetes secrets managed via External Secrets Operator
- IAM roles assigned per workload
- No hardcoded credentials in repository

## Observability

Voyager includes a full monitoring stack:

- Prometheus → metrics collection
- Grafana → dashboards
- Loki → log aggregation

This enables:

- Cluster health monitoring
- Application performance tracking
- Infrastructure observability

## CI/CD Pipeline

Implemented in GitLab CI:

- Frontend build
- Docker image builds
- Push to AWS ECR
- Helm chart updates
- ArgoCD sync trigger
- Manual production deployment gates
- Rollback capability for production

## What This Project Demonstrates

This repository demonstrates practical experience with:

- Cloud-native architecture (AWS + Kubernetes)
- Infrastructure as Code (Terraform)
- GitOps workflows (ArgoCD)
- CI/CD pipeline design
- Observability and monitoring integration

## Summary

Voyager is a cloud-native full-stack platform that simulates real-world
production infrastructure using modern DevOps engineering practices.
