# Cloud Provider Comparison Document

> **Project:** Cloud Cartographer  
> **Compared providers:** Amazon Web Services (AWS) and Google Cloud Platform (GCP)  
> **Target application:** React frontend + Go backend + PostgreSQL  
> **Target scale:** up to 1,000 simultaneous active users

## 1. Why AWS and GCP

AWS and GCP were selected because both are strong fits for a Kubernetes-based migration project with managed database, private networking, self-hosted monitoring, GitOps deployment, and CI/CD integration.

### 1.1 Reasons for choosing AWS

- very strong market adoption and mature ecosystem
- direct service mapping for almost every requirement
- EKS, RDS, ECR, Route 53, ACM, and S3 fit the assignment very nicely
- strong IAM, networking, and DNS capabilities for private-by-default infrastructure

### 1.2 Reasons for choosing GCP

- GKE has a strong reputation for Kubernetes experience
- Cloud SQL, Artifact Registry, Cloud DNS, and load balancers map cleanly to the same architecture

### 1.3 Why Azure was not selected

Azure is a valid cloud provider, but since the project already has a clear Kubernetes and managed database focus, AWS and GCP are the most practical pair to compare.

## 2. High-Level Recommendation

If the goal is **the most direct path for this project**, AWS is the better fit.

If the goal is **a strong Kubernetes-focused alternative with a clean managed platform experience**, GCP is also a very good choice.

### Summary recommendation

| Provider | Recommendation |
|---|---|
| AWS | Best overall fit for the target architecture |
| GCP | Strong comparison provider and realistic alternative |

Reason:

- AWS service names and patterns match the assignment very directly
- AWS has especially strong support for private networking, DNS, certificate management, and managed PostgreSQL in this design
- GCP remains highly competitive, especially for Kubernetes operations

## 3. Service Mapping

### 3.1 Core application and platform services

| Requirement | AWS | GCP | Notes |
|---|---|---|---|
| Kubernetes cluster | EKS Standard | GKE Standard | Autopilot/Auto Mode should not be used |
| Worker nodes | EC2 managed node groups | GCE node pools | Separate pools for main, monitoring, and tools |
| Managed PostgreSQL | RDS PostgreSQL | Cloud SQL for PostgreSQL | Production should use HA |
| Container registry | ECR | Artifact Registry | Shared account/project usage recommended |
| Public DNS | Route 53 public hosted zone | Cloud DNS public zone | For frontend and public services |
| Private DNS | Route 53 private hosted zone | Cloud DNS private zone | For internal-only service naming |
| Public load balancer | ALB | External HTTP(S) Load Balancer | Frontend and public API entry |
| Private load balancer | Internal ALB or NLB | Internal load balancer | For internal services when needed |
| TLS certificates | ACM | Google-managed certificates / Certificate Manager | Public HTTPS termination |
| Object storage | S3 | Cloud Storage | Logs, backups, artifacts |
| Secret manager | AWS Secrets Manager | Google Secret Manager | Used with External Secrets |
| VPN / private access | AWS Client VPN / self-managed WireGuard | Cloud VPN / self-managed WireGuard | Required for private cluster access |

### 3.2 CI/CD and GitOps related services

| Requirement | AWS | GCP | Notes |
|---|---|---|---|
| Git hosting / CI | GitLab (hosted or self-managed) | GitLab (hosted or self-managed) | Same external tool choice on both clouds |
| CD | ArgoCD on Kubernetes | ArgoCD on Kubernetes | Self-hosted for both |
| Helm chart storage | OCI in ECR or Git repo | OCI in Artifact Registry or Git repo | OCI is preferred but not mandatory |

### 3.3 Monitoring and logging

| Requirement | AWS | GCP | Notes |
|---|---|---|---|
| Metrics | Prometheus self-hosted | Prometheus self-hosted | Managed services are not allowed |
| Dashboards | Grafana self-hosted | Grafana self-hosted | Same for both |
| Logs | Loki self-hosted | Loki self-hosted | Same for both |
| Log shipping | Promtail or Alloy | Promtail or Alloy | Same for both |

## 4. Free Tier Comparison

Free tier should be treated as a dev plan, not a production plan.

### 4.1 Free tier overview

| Area | AWS | GCP | Practical meaning |
|---|---|---|---|
| Account credits | New customers may get up to $200 in credits | GCP promotions vary by offer | Credits help with setup but do not replace real cost planning |
| Compute | Some free usage for limited period | Always Free exists for some small compute resources | Not enough for full target architecture |
| Managed Kubernetes | No meaningful free EKS equivalent | GKE pricing may be favorable depending on cluster mode and offer structure | Still not enough for full required setup |
| Managed PostgreSQL | Limited and temporary benefits only | No meaningful free production DB tier for this use case | DB should be assumed paid |
| Object storage | Small free allowance | Small free allowance | Useful only for tiny experimental use |

Duration:

- AWS - 12months

- GCP - 90 Days

### 4.2 Free tier relevance to this project

| Component | Can free tier realistically cover it? | Reason |
|---|---|---|
| Frontend experiments | Partially | Tiny compute can host simple experiments |
| Backend experiments | Partially | Small low-load testing only |
| Production-like Kubernetes | No | Cluster, nodes, and networking exceed free-tier scale |
| Production database | No | HA database and backups are clearly paid resources |
| Monitoring stack | No | Prometheus, Grafana, and Loki need compute and storage |
| NAT, LB, DNS, VPN | No | These are classic hidden-cost infrastructure services |

Conclusion:

- Free tiers are useful for first experimentation.
- They are not enough for the required full infrastructure running from month to month.

## 5. Pricing Model Comparison

### 5.1 On-demand vs committed vs spot/preemptible

| Pricing model | AWS | GCP | Tradeoff |
|---|---|---|---|
| On-demand | EC2 on-demand | Standard VM pricing | Most flexible, highest steady-state cost |
| Spot / preemptible | EC2 Spot | Spot / preemptible style pricing | Large savings, but interruptions must be tolerated |
| Reserved / committed | Savings Plans / Reserved Instances | Committed use discounts | Best for long-running stable production resources |

### 5.2 Best use of pricing models in this project

| Workload | Best model | Reason |
|---|---|---|
| Test environment | Small on-demand, with optional scheduled shutdown | Keeps things simple and cheap |
| Production main workloads | On-demand initially, then committed once usage is stable | Avoid overcommitting too early |
| Database | On-demand managed DB initially | Databases are stateful and should not use interruption-based pricing |

## 6. Provider Strengths and Weaknesses

### 6.1 AWS

#### Strengths

- direct service mapping to all assignment requirements
- very mature IAM, networking, DNS, and managed database options
- strong ecosystem around EKS and GitOps workflows
- Route 53, ACM, ECR, and RDS integrate naturally with the target architecture

#### Weaknesses

- pricing structure can become confusing quickly
- NAT, data transfer, and load balancer charges need close attention
- EKS operational complexity is still real even though the control plane is managed

### 6.2 GCP

#### Strengths

- strong Kubernetes story through GKE
- clean managed services around networking and container workloads
- good fit for Kubernetes-centered infrastructure planning
- Cloud DNS and Cloud SQL are straightforward to reason about

#### Weaknesses

- still requires careful cost planning around networking and storage growth
- some teams may find AWS ecosystem examples easier to find for enterprise-style setups
- some teams may find AWS reference material and common enterprise deployment patterns easier to find for this style of architecture

## 7. Mapping of Project Requirements to AWS and GCP

### 7.1 Networking and security

| Requirement | AWS | GCP |
|---|---|---|
| Separate environments | Separate AWS accounts or strong logical separation | Separate GCP projects or strong logical separation |
| Private cluster nodes | Private EKS node groups in private subnets | Private GKE nodes in private subnets |
| No public DB IP | Private RDS | Private Cloud SQL |
| Public and private DNS | Route 53 public/private zones | Cloud DNS public/private zones |
| TLS certs | ACM | Google-managed certs / Certificate Manager |
| Secrets | AWS Secrets Manager | Google Secret Manager |

### 7.2 Application delivery and operations

| Requirement | AWS | GCP |
|---|---|---|
| GitOps deployment | ArgoCD on EKS | ArgoCD on GKE |
| Helm-based app delivery | Yes | Yes |
| External DNS automation | Route 53 integration | Cloud DNS integration |
| External Secrets | Secrets Manager integration | Secret Manager integration |
| Monitoring stack | Self-hosted on EKS | Self-hosted on GKE |

## 8. Which Provider Best Fits Each Part

| Area | Better fit | Why |
|---|---|---|
| Private-by-default networking model | AWS | Route 53, ACM, IAM, VPC, and RDS form a very common pattern for this architecture |
| Kubernetes experience | GCP slightly | GKE is widely seen as very polished |
| DNS and certificate flow | AWS slightly | Route 53 + ACM is a very familiar pattern |
| Managed PostgreSQL | Tie | RDS and Cloud SQL both fit well |
| GitOps / ArgoCD | Tie | Works well on either |
| Registry integration | Tie | ECR and Artifact Registry are both suitable |

## 9. Final Provider Comparison Conclusion

Both AWS and GCP are valid solutions for this project.

The comparison shows:

- both can satisfy the infrastructure requirements
- both support Kubernetes, managed PostgreSQL, private networking, DNS automation, and secret management
- both can host the full self-managed monitoring and GitOps stack required by the assignment

The final recommendation is:

- **Use AWS as the primary provider**
- **Use GCP as the formal comparison provider**

This is the most practical path because:

- AWS maps very directly to the required architecture
- AWS has strong service maturity in IAM, DNS, TLS, private networking, and managed PostgreSQL
- it still provides a meaningful comparison against another top-tier cloud provider

## 10. Official Pricing and Service References

These are the official sources for Pricin and Services

### AWS

- [AWS Pricing Calculator](https://calculator.aws/)
- [Amazon EKS Pricing](https://aws.amazon.com/eks/pricing/)
- [Amazon EC2 Pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [Amazon RDS Pricing](https://aws.amazon.com/rds/postgresql/pricing/)
- [Amazon ECR Pricing](https://aws.amazon.com/ecr/pricing/)
- [Amazon Route 53 Pricing](https://aws.amazon.com/route53/pricing/)
- [Amazon S3 Pricing](https://aws.amazon.com/s3/pricing/)
- [AWS Client VPN Pricing](https://aws.amazon.com/vpn/pricing/)

### GCP

- [Google Cloud Pricing Calculator](https://cloud.google.com/products/calculator)
- [GKE Pricing](https://cloud.google.com/kubernetes-engine/pricing)
- [Compute Engine Pricing](https://cloud.google.com/compute/all-pricing)
- [Cloud SQL Pricing](https://cloud.google.com/sql/pricing)
- [Artifact Registry Pricing](https://cloud.google.com/artifact-registry/pricing)
- [Cloud DNS Pricing](https://cloud.google.com/dns/pricing)
- [Cloud Storage Pricing](https://cloud.google.com/storage/pricing)
- [Cloud VPN Pricing](https://cloud.google.com/network-connectivity/docs/vpn/pricing)
