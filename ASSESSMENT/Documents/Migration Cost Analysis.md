# Migration Cost Analysis

> **Project:** Cloud Cartographer  
> **Compared providers:** AWS and GCP  
> **Target application:** React frontend + Go backend + PostgreSQL  
> **Target scale:** up to 1,000 simultaneous active users

## 1. Scope and Assumptions

This document estimates the monthly cost of running the target cloud architecture on:

- Amazon Web Services (AWS)
- Google Cloud Platform (GCP)

These are **planning estimates**, not final invoices.

### 1.1 What is included

- shared resources
- test environment
- production environment
- Kubernetes control plane
- worker nodes for `main`, `monitoring`, and `tools`
- managed PostgreSQL
- DNS
- container registry
- object storage for logs / general storage
- load balancer cost baseline
- NAT baseline

### 1.2 What is not fully modeled

- tax / VAT
- exact egress by geographic destination
- support plans
- enterprise discounts
- future reserved / committed discounts

### 1.3 Pricing method

The prices below are:

- based on official provider pricing pages and pricing calculators
- rounded for readability
- expressed in **USD per month**
- intended for migration planning, not procurement approval

### 1.4 Architecture assumptions

#### Shared account / project

- private container registry
- DNS zones
- lightweight VPN / admin-access helper
- minimal state / storage support

#### Test environment

- one Kubernetes cluster
- smaller worker nodes
- no production-grade HA for application and DB
- lower-cost managed PostgreSQL

#### Production environment

- one Kubernetes cluster
- multi-node pools
- highly available managed PostgreSQL
- public frontend
- full monitoring stack

## 2. Sizing Basis

The cost estimate is based on the Infrastructure Analysis Report findings:

- frontend is lightweight
- backend is the first meaningful scaling pressure point
- PostgreSQL becomes more relevant as concurrency rises
- 20 and 50 user runs were clean
- 100 user run showed instability, so production must include headroom

## 3. AWS Full Cloud Implementation Estimate

### 3.1 Shared resources

| Component | Monthly estimate | Notes |
|---|---:|---|
| ECR storage | $1 | Assumes about 10 GB of private image storage at roughly $0.10/GB-month |
| Route 53 hosted zones | $2 | Assumes 4 hosted zones at $0.50 each |
| Lightweight admin/VPN helper VM + disk | $17 | Small EC2 instance plus basic EBS |
| Shared S3 / misc storage | $2 | State, small artifacts, misc storage |
| **Shared subtotal** | **$22** | |

### 3.2 Test environment

| Component | Monthly estimate | Notes |
|---|---:|---|
| EKS control plane | $73 | At $0.10/hour |
| Main node group | $31 | One small general-purpose node |
| Monitoring node group | $31 | One small general-purpose node |
| Tools node group | $15 | One smaller tooling node |
| RDS PostgreSQL test instance + storage | $55 | Small non-HA managed PostgreSQL estimate |
| NAT gateway baseline | $35 | Hourly gateway plus light traffic processing |
| Public load balancer baseline | $33 | ALB baseline using AWS example pricing |
| S3 logs / object storage | $3 | Light test retention |
| Misc networking / IP overhead | $5 | Buffer for small network/IP items |
| **Test subtotal** | **$281** | |

### 3.3 Production environment

| Component | Monthly estimate | Notes |
|---|---:|---|
| EKS control plane | $73 | One production cluster |
| Main node group | $183 | Three larger general-purpose nodes |
| Monitoring node group | $122 | Two larger monitoring nodes |
| Tools node group | $61 | Two medium tooling nodes |
| RDS PostgreSQL prod HA + storage + backups | $220 | HA managed PostgreSQL planning estimate |
| NAT gateways baseline | $106 | Three-AZ-style production posture plus traffic processing buffer |
| Load balancer baseline | $66 | Public + internal style baseline |
| S3 logs / object storage | $15 | Larger retention footprint |
| Misc networking / IP overhead | $15 | Buffer for public IPv4 and similar items |
| **Production subtotal** | **$861** | |

### 3.4 AWS total

| Scope | Monthly estimate |
|---|---:|
| Shared | $22 |
| Test | $281 |
| Production | $861 |
| **AWS total** | **$1,164 / month** |

## 4. GCP Full Cloud Implementation Estimate

### 4.1 Shared resources

| Component | Monthly estimate | Notes |
|---|---:|---|
| Artifact Registry storage | $1 | Assumes around 10 GB, after first 0.5 GB free |
| Cloud DNS managed zones | $1 | Assumes 4 zones at $0.20 each |
| Lightweight admin/VPN helper VM + disk | $13 | Small Compute Engine VM plus small disk |
| Shared Cloud Storage / misc | $1 | State, small artifacts, misc storage |
| **Shared subtotal** | **$16** | |

### 4.2 Test environment

| Component | Monthly estimate | Notes |
|---|---:|---|
| GKE cluster management fee | $0 | One zonal cluster effectively offset by the GKE free tier credit |
| Main node pool | $24 | One `e2-medium` class node |
| Monitoring node pool | $24 | One `e2-medium` class node |
| Tools node pool | $12 | One smaller tooling node |
| Cloud SQL test instance | $26 | `db-g1-small` style estimate |
| Cloud NAT baseline | $9 | Public NAT example sized for a small test setup |
| External load balancer baseline | $18 | Forwarding rule baseline |
| Cloud Storage logs | $2 | Light log storage |
| Misc networking overhead | $5 | Small buffer |
| **Test subtotal** | **$120** | |

### 4.3 Production environment

| Component | Monthly estimate | Notes |
|---|---:|---|
| GKE cluster management fee | $73 | $0.10/hour |
| Main node pool | $147 | Three `e2-standard-2` class nodes |
| Monitoring node pool | $98 | Two `e2-standard-2` class nodes |
| Tools node pool | $24 | One `e2-medium` class node |
| Cloud SQL prod HA + storage + backups | $180 | HA production planning estimate |
| Cloud NAT baseline | $20 | More instances and more processed traffic |
| Load balancer baseline | $37 | Public + private forwarding-rule style estimate |
| Cloud Storage logs | $10 | Larger retention footprint |
| Misc networking overhead | $8 | Small production buffer |
| **Production subtotal** | **$597** | |

### 4.4 GCP total

| Scope | Monthly estimate |
|---|---:|
| Shared | $16 |
| Test | $120 |
| Production | $597 |
| **GCP total** | **$733 / month** |

## 5. Side-by-Side Comparison

### 5.1 Total monthly estimate

| Provider | Shared | Test | Production | Total |
|---|---:|---:|---:|---:|
| AWS | $22 | $281 | $861 | **$1,164** |
| GCP | $16 | $120 | $597 | **$733** |

### 5.2 Cost by major component category

#### AWS

| Category | Approximate monthly cost |
|---|---:|
| Kubernetes control planes | $146 |
| Compute node groups | $443 |
| Managed PostgreSQL | $275 |
| Networking (NAT + LB + DNS + IP overhead) | $262 |
| Registry and object storage | $21 |
| Shared admin/VPN support | $17 |

#### GCP

| Category | Approximate monthly cost |
|---|---:|
| Kubernetes control planes | $73 |
| Compute node pools | $329 |
| Managed PostgreSQL | $206 |
| Networking (NAT + LB + DNS + overhead) | $80 |
| Registry and object storage | $14 |
| Shared admin/VPN support | $13 |

### 5.3 Interpretation

GCP comes out noticeably cheaper in this planning estimate. The biggest reasons are:

- the GKE free tier credit helps reduce test cluster management cost
- GCP node pricing is favorable in the selected reference machine types
- the modeled networking baseline is lower in this estimate than the AWS NAT + ALB combination

AWS remains a valid choice despite the higher estimate because:

- the AWS service mapping is very direct
- Route 53, ACM, ECR, RDS, and EKS are a very natural fit for the target design
- AWS also has a very strong private-networking, IAM, DNS, and certificate-management model for this architecture

### 5.4 Billing Alert and Budget Implementation

#### AWS

- Create a budget in AWS Billing Console under **Budgets**
- Set a monthly cost budget per account (shared, test, prod separately)
- Add alert thresholds at 50%, 80%, and 100% of budget
- Send alerts to an email or SNS topic
- Use AWS Cost Explorer to review spending weekly

#### GCP

- Create a budget in **Billing > Budgets & alerts** in the GCP Console
- Set per-project budgets (shared, test, prod separately)
- Add alert thresholds at 50%, 80%, and 100%
- Send alerts via email or Pub/Sub
- Use GCP Cost Table reports to review spending weekly

#### Suggested budget thresholds based on cost estimates

| Environment | AWS budget | GCP budget |
|---|---:|---:|
| Shared | $30/month | $20/month |
| Test | $320/month | $140/month |
| Production | $950/month | $650/month |

#### Resource Monitoring and Cost Tracking Strategy

- Tag all resources with `environment` (shared/test/prod), `owner`, and `component` from day one
- Use AWS Cost Explorer / GCP Cost Table to review spend weekly, broken down by tag
- Enable AWS CloudTrail / GCP Audit Logs to track all resource changes
- Review Kubernetes resource requests and limits monthly and adjust if nodes are over or underutilized
- Set up a monthly cost review to compare actual vs estimated spend and adjust budgets if needed

#### Automated Cleanup Policies

| Resource | Policy | Tool |
|---|---|---|
| Container images | Delete untagged images older than 7 days, keep last 10 tagged versions | ECR lifecycle policy / Artifact Registry cleanup policy |
| Application logs | Expire logs after 1 year | S3 lifecycle rule / GCS object lifecycle rule |
| Database backups | Retain 30 daily backups for prod, 7 for test, auto-expire older ones | RDS / Cloud SQL automated backup retention settings |
| Prometheus metrics | Retain 30 days, auto-purge older data | Prometheus `--storage.tsdb.retention.time=30d` flag |
| Loki logs | Retain 1 year, auto-purge older chunks | Loki `retention_period` configuration |
| Test environment VMs | Shut down outside working hours (e.g. 08:00–18:00 weekdays) | AWS Instance Scheduler / GCP Cloud Scheduler + Cloud Functions |

### 5.4 Testing Methodology for Cloud Environment

| Phase | What to test | How |
|---|---|---|
| Infrastructure | Nodes, networking, DNS, TLS, private access | Deploy to test environment first, verify connectivity and access before prod |
| Application | Frontend, backend, database connectivity | Smoke test after each deployment via ArgoCD sync |
| Load | Backend scaling under concurrent users | Run Locust against test environment, verify HPA triggers correctly |
| Database | Backup and restore | Periodically restore a backup to a separate instance and verify data integrity |
| Failover | HA behavior | Simulate node or AZ failure in test, verify pods reschedule and DB fails over |
| Security | Private access, no public IPs, secret injection | Verify no public endpoints exist on nodes or DB, confirm secrets are injected correctly |
| CI/CD | Pipeline end-to-end | Trigger a full build and deployment to test before promoting to prod |

## 6. Hidden Cost Considerations

These totals are not the whole story. The following costs can increase the bill significantly if they are ignored.

### 6.1 Data transfer

- internet egress from the frontend
- traffic through NAT
- cross-AZ / cross-zone traffic
- pulling images across clusters or regions

### Data Transfer Cost Calculations

#### Assumptions

| Parameter | Value | Reasoning |
|---|---|---|
| Simultaneous users | 1,000 | Target production scale |
| Requests per user per minute | 5 | Reasonable estimate for a simple login/register/ping app |
| Average response size | 3 KB | Midpoint of small (~1-5 KB) range |
| Active hours per day | 12 | Conservative estimate |
| Days per month | 30 | |

#### Monthly egress calculation

| Step | Calculation | Result |
|---|---|---|
| Requests per minute | 1,000 users × 5 req/min | 5,000 req/min |
| Data per minute | 5,000 × 3 KB | 15,000 KB = ~15 MB/min |
| Data per hour | 15 MB × 60 | ~900 MB/hour |
| Data per day | 900 MB × 12 hours | ~10.8 GB/day |
| Data per month | 10.8 GB × 30 days | ~324 GB/month |

#### Cost estimate

| Provider | First 1 GB | After 1 GB rate | Estimated monthly egress cost |
|---|---|---|---|
| AWS | Free | ~$0.09/GB | ~$29/month (324 GB × $0.09) |
| GCP | Free | ~$0.08/GB | ~$26/month (324 GB × $0.08) |

Pricing based on AWS and GCP standard internet egress rates.

### 6.2 Storage growth

- one year of logs can become large even if the app is small
- database backups grow over time
- old container images accumulate unless lifecycle policies are enforced

### 6.3 Monitoring overhead

- Prometheus storage grows with retention and metric volume
- Loki storage grows with log volume and retention length
- dashboards are cheap, but metrics and logs are not

### 6.4 Public IP and managed networking charges

- AWS public IPv4 charges now matter
- NAT gateways are expensive when left running all month
- load balancers have always-on baseline cost

### 6.5 Operational extras

- CI/CD runners
- VPN access
- secret management calls
- backup restore testing
- failed deployments that repeatedly pull images

## 7. Benefits and Drawbacks of Full Cloud Implementation

### 7.1 Benefits

- managed database reduces risk and ops burden
- easy horizontal scaling for frontend and backend
- stronger HA options than a local-only setup
- better observability and operational maturity
- clear separation between shared, test, and prod environments

### 7.2 Drawbacks

- recurring monthly cost is real even for a relatively small application
- networking and observability create meaningful overhead
- production-grade HA increases spend quickly
- cloud cost discipline becomes part of engineering, not an afterthought

## 8. Cost Optimization Opportunities

### 8.1 Test environment

- shut test down outside working hours
- use smaller node pools initially
- delay HA where the assignment allows it

### 8.2 Tooling

- use spot / preemptible capacity where interruption is acceptable
- keep tooling node pools minimal

### 8.3 Storage

- apply lifecycle policies to images and logs
- archive old logs to cheaper storage classes
- keep backup retention realistic for test

### 8.4 Long-running production

- after usage stabilizes, evaluate:
  - AWS Savings Plans / Reserved Instances
  - GCP committed use discounts

## 9. Final Cost Conclusion

For this migration design:

- **AWS estimate:** about **$1,164/month**
- **GCP estimate:** about **$733/month**

If the main goal is **lowest estimated monthly cost in this planning model**, GCP looks better.

If the main goal is **the strongest service fit for a private-by-default Kubernetes architecture**, AWS remains a very practical choice.

The cost difference is important, but it is not the only decision factor. This project also cares about:

- service fit
- implementation simplicity
- security controls
- deployment workflow
- learning curve

That is why AWS can still be the right implementation choice even if GCP appears cheaper in this planning estimate.

## 10. Official Pricing References

### AWS

- [Amazon EKS FAQ pricing summary](https://aws.amazon.com/id/eks/faqs/)
- [Amazon EC2 pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [Amazon EC2 T3 instance family](https://aws.amazon.com/es/ec2/instance-types/t3/)
- [Amazon RDS for PostgreSQL pricing](https://aws.amazon.com/rds/postgresql/pricing)
- [Amazon ECR pricing](https://aws.amazon.com/ecr/pricing/?did=ap_card)
- [Amazon Route 53 pricing](https://aws.amazon.com/route53/pricing/)
- [Amazon VPC / NAT Gateway pricing](https://aws.amazon.com/vpc/pricing/?linkId=524222313&sc_campaign=Support&sc_channel=sm&sc_content=Support&sc_country=global&sc_geo=GLOBAL&sc_outcome=AWS+Support&sc_publisher=REDDIT&trk=Support)
- [NAT Gateway pricing details](https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-pricing.html)
- [Elastic Load Balancing pricing](https://aws.amazon.com/elasticloadbalancing/pricing/?loc=3&nc=sn)
- [AWS VPN pricing](https://aws.amazon.com/vpn/pricing//)
- [AWS public IPv4 pricing announcement](https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights/)
- [Amazon S3 pricing](https://aws.amazon.com/s3/pricing)
- [AWS Pricing Calculator](https://calculator.aws/)

### GCP

- [GKE pricing](https://cloud.google.com/kubernetes-engine/pricing?hl=en_GB)
- [Compute Engine pricing](https://cloud.google.com/compute/all-pricing?hl=en)
- [Cloud SQL pricing](https://cloud.google.com/sql/pricing/)
- [Cloud DNS pricing](https://cloud.google.com/dns/pricing)
- [Artifact Registry pricing](https://cloud.google.com/artifact-registry/pricing)
- [Cloud NAT pricing](https://cloud.google.com/nat/pricing)
- [Cloud Load Balancing pricing](https://cloud.google.com/load-balancing/pricing?authuser=2)
- [Cloud Storage pricing](https://cloud.google.com/storage/pricing?hl=en)
- [Cloud VPN pricing](https://cloud.google.com/vpn/pricing?hl=de)
- [Google Cloud Pricing Calculator](https://cloud.google.com/products/calculator)
