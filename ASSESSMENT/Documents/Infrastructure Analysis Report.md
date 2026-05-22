# Infrastructure Analysis Report

> **Project:** Cloud Cartographer  
> **Application:** React frontend + Go Fiber backend + PostgreSQL  
> **Target production scale:** up to 1,000 simultaneous active users

## 1. Cloud Deployment Models

This project requires a mixed cloud model. Some parts should stay self-managed because of the assignment requirements, while other parts are better handled by managed cloud services.

### 1.1 IaaS vs PaaS vs SaaS

| Model | Meaning | What we manage |
|---|---|---|---|
| IaaS | Raw compute, storage, and networking resources | Node sizing, workload placement, self-hosted tools such as: Kubernetes worker nodes, self-hosted monitoring stack |
| PaaS | Managed platform services | Service configuration, data, access policies, such as: Managed PostgreSQL, DNS, load balancers, container registry |
| SaaS | Fully managed software products | User/admin configuration only, such as: self-managed GitLab |

### 1.2 Component classification

| Component | Cloud equivalent | Model | Reason |
|---|---|---|---|
| Frontend | Pods on EKS/GKE worker nodes | IaaS-leaning | We build and operate the image ourselves |
| Backend | Pods on EKS/GKE worker nodes | IaaS-leaning | We manage scaling behavior and runtime config |
| Kubernetes control plane | EKS / GKE Standard | PaaS | Provider manages the control plane |
| PostgreSQL | RDS PostgreSQL / Cloud SQL PostgreSQL | PaaS | Managed backups, HA, and recovery are practical here |
| Prometheus / Grafana / Loki | Self-hosted on Kubernetes | IaaS | Managed monitoring is not allowed by the assignment |
| ArgoCD | Self-hosted on Kubernetes | IaaS | GitOps tool operated by us |
| Container registry | ECR / Artifact Registry | PaaS | Managed image storage is the right tradeoff |
| DNS | Route 53 / Cloud DNS | PaaS | Managed DNS is more reliable and easier to operate |
| Load balancer | ALB / GCP HTTP(S) LB | PaaS | Managed ingress is operationally simpler |

## 2. CapEx vs OpEx in Cloud Context

### 2.1 Definitions

| Model | Meaning | Practical effect on this project |
|---|---|---|
| CapEx | Upfront spending on physical servers, storage, networking, and related hardware | High initial investment, slower scaling, hardware lifecycle responsibility |
| OpEx | Ongoing monthly cloud spending based on resource usage | Lower entry cost, easier scaling, recurring bill that must be controlled |

### 2.2 Why OpEx fits this project

For this project, OpEx is the better model because:

- the infrastructure can be created gradually
- a smaller test environment can be kept cheap
- production can be sized with autoscaling and HA
- managed services reduce operational burden

The downside is cost unpredictability. NAT, storage growth, logging, and data transfer can quietly increase monthly spend, so billing alerts and tagging are essential.

## 3. Performance Baseline

### 3.1 Measurement methodology

The local baseline was measured from the Docker Compose version of the sample application.

Tools used:

| Tool | Purpose |
|---|---|
| `docker compose` | Start the app locally |
| `docker stats` | Capture repeated CPU and memory snapshots per container |
| Prometheus | Collect time-series metrics |
| Grafana | Visualize metrics |
| cAdvisor | Expose container-level metrics |
| Postgres Exporter | Expose PostgreSQL metrics |
| Locust | Generate repeatable traffic at different user counts |

Test process:

1. Start the app stack and local monitoring stack.
2. Verify the real backend responds with `pong` on `/api/ping`.
3. Run Locust at 20, 50, and 100 virtual users.
4. Collect repeated `docker stats` snapshots into CSV.
5. Summarize average and peak CPU/memory values per container.

### 3.3 Resource utilization per component

#### 20-user run

| Component | Avg CPU % | Peak CPU % | Avg Mem % | Peak Mem % |
|---|---:|---:|---:|---:|
| Frontend | 0.00 | 0.00 | 0.03 | 0.03 |
| Backend | 23.23 | 69.16 | 0.10 | 0.11 |
| PostgreSQL | 2.64 | 7.18 | 0.97 | 0.99 |
| Prometheus | 0.08 | 0.52 | 0.57 | 0.59 |
| Grafana | 0.12 | 0.68 | 0.64 | 0.70 |
| cAdvisor | 0.78 | 2.71 | 0.34 | 0.40 |
| Postgres Exporter | 0.18 | 1.73 | 0.10 | 0.10 |

#### 50-user run

| Component | Avg CPU % | Peak CPU % | Avg Mem % | Peak Mem % |
|---|---:|---:|---:|---:|
| Frontend | 0.00 | 0.00 | 0.03 | 0.03 |
| Backend | 48.48 | 112.48 | 0.16 | 0.19 |
| PostgreSQL | 3.15 | 7.50 | 2.00 | 2.07 |
| Prometheus | 0.27 | 2.20 | 0.60 | 0.61 |
| Grafana | 0.05 | 0.10 | 0.56 | 0.57 |
| cAdvisor | 0.95 | 2.27 | 0.42 | 0.44 |
| Postgres Exporter | 0.45 | 2.05 | 0.10 | 0.10 |

#### 100-user run

| Component | Avg CPU % | Peak CPU % | Avg Mem % | Peak Mem % |
|---|---:|---:|---:|---:|
| Frontend | 0.00 | 0.00 | 0.03 | 0.03 |
| Backend | 10.18 | 69.00 | 0.24 | 0.26 |
| PostgreSQL | 5.66 | 8.49 | 2.61 | 2.65 |
| Prometheus | 0.02 | 0.07 | 0.63 | 0.63 |
| Grafana | 0.05 | 0.12 | 0.56 | 0.56 |
| cAdvisor | 0.34 | 0.91 | 0.41 | 0.43 |
| Postgres Exporter | 0.00 | 0.00 | 0.10 | 0.11 |

### 3.4 Request-level benchmark observations

#### 20 users

- No request failures
- Aggregated average response time: about `29.86 ms`
- Backend login and registration were the slowest actions, which is expected because they involve password handling and database work

#### 50 users

- No request failures
- Aggregated average response time: about `28.02 ms`
- The backend CPU load increased sharply compared with the 20-user run
- The system still completed the test cleanly

#### 100 users

- The run became unstable
- `POST /api/login` produced many `401 Unauthorized` failures
- `POST /api/register` produced `500 Internal Server Error` failures
- Aggregated failures: `1501`

Failure summary from the 100-user run:

| Endpoint | Error | Occurrences |
|---|---|---:|
| `/api/login` | `401 Unauthorized` | 1429 |
| `/api/register setup` | `500 Internal Server Error` | 72 |

### 3.5 Main observations

#### Frontend

- The frontend stayed nearly idle in all runs.
- This matches the expected behavior of a small static frontend served by Nginx.
- It is not the first scaling concern.

#### Backend

- The backend is the most CPU-sensitive application component.
- At 20 users, it already averaged `23.23%` CPU.
- At 50 users, it averaged `48.48%` CPU and peaked above `100%`, which is the strongest sign of local application pressure.
- The backend is the most likely first workload that will need horizontal scaling in cloud.

#### Database

- PostgreSQL stayed moderate in the clean 20 and 50 user runs.
- By the 100-user run, DB memory percentage increased noticeably.
- The DB does not look like the first bottleneck at lower loads, but it becomes more relevant as concurrency rises.

#### Monitoring overhead

- Prometheus, Grafana, cAdvisor, and Postgres Exporter all consumed real resources.
- The monitoring stack is lightweight compared with the app, but it is not free and must be included in cloud sizing and cost estimates.

### 3.6 Performance bottlenecks and scaling implications

| Area | Observation | Implication |
|---|---|---|
| Backend CPU | Strongest pressure point in the clean runs | Backend should be the first workload scaled horizontally |
| Database memory / write path | More visible growth at higher concurrency | Managed PostgreSQL with backups and HA is justified in production |
| Registration/login path | Highest latency and first visible failures at 100 users | Auth flow needs attention under concurrency; backend and DB sizing should account for this |
| Frontend | Very light load | Frontend can stay small and scale cheaply |

### 3.7 Resource constraints and scaling criteria

Suggested initial scaling triggers for the cloud design:

| Component | Suggested trigger | Scaling action |
|---|---|---|
| Backend | CPU above 70% or growing latency/error rate | Add replicas with HPA |
| Frontend | Sustained CPU growth or rising ingress throughput | Add replicas |
| PostgreSQL | Connection pressure, rising latency, storage growth | Increase instance size or add pooling |
| Prometheus | Rising retention pressure or memory growth | Increase memory/disk and tune retention |
| Loki / logs | Retention cost or storage growth | Tier old logs to cheaper object storage |

### 3.8 Baseline limitations

These results are useful for infrastructure planning, but not enough to claim production readiness for 1,000 simultaneous users.

Reasons:

- local Docker Desktop on Windows adds overhead
- the app and load generator run on the same machine
- local testing is a baseline, not a production-grade performance environment
- the 100-user run already shows instability, which means simple linear scaling assumptions must be treated carefully

Therefore, the local measurements should be used to:

- identify likely bottlenecks
- justify relative sizing decisions
- support cloud architecture reasoning

They should not be used to claim:

- proven 1,000-user production readiness
- exact cloud instance sizing without safety margins

## 4. Dependency Analysis

### 4.1 Current local dependency map

The current local application path is:

- User -> Frontend -> Backend -> PostgreSQL

The local monitoring path is:

- Prometheus -> cAdvisor
- Prometheus -> Postgres Exporter -> PostgreSQL
- Grafana -> Prometheus

### 4.2 Current local service dependencies with ports

| Source | Destination | Port | Protocol | Action on that port |
|---|---|---:|---|---|
| User browser | Frontend | 3000 | HTTP | Loads the React UI and static assets |
| Frontend | Backend API | 8080 | HTTP | Sends login, register, logout, session, and ping requests |
| Backend | PostgreSQL | 5432 | TCP/PostgreSQL | Reads and writes user data |
| Docker healthcheck | PostgreSQL | 5432 | TCP/PostgreSQL | Checks DB readiness |
| Prometheus | Prometheus | 9090 | HTTP | Self-scrape |
| Prometheus | cAdvisor | 8080 | HTTP | Scrapes container metrics |
| Prometheus | Postgres Exporter | 9187 | HTTP | Scrapes DB metrics |
| Postgres Exporter | PostgreSQL | 5432 | TCP/PostgreSQL | Reads database statistics |
| Grafana | Prometheus | 9090 | HTTP | Queries metrics for dashboards |
| User browser | Grafana | 3001 | HTTP | Manual dashboard access |

### 4.3 Target cloud service dependencies with ports

| Source | Destination | Port | Protocol | Action on that port |
|---|---|---:|---|---|
| User browser | Public load balancer / ingress | 443 | HTTPS | Public frontend access |
| User browser | Public load balancer / ingress | 80 | HTTP | Redirect to HTTPS |
| Load balancer / ingress | Frontend pods | 3000 | HTTP | Route UI traffic |
| Frontend | Backend API ingress | 443 | HTTPS | Secure API calls |
| Backend ingress | Backend pods | 8080 | HTTP | Route API traffic |
| Backend pods | Managed PostgreSQL | 5432 | TCP/PostgreSQL | Data reads and writes |
| External Secrets | AWS Secrets Manager / equivalent | 443 | HTTPS | Pull application secrets |
| External DNS | Route 53 / equivalent | 443 | HTTPS | Create DNS records automatically |
| ArgoCD | Git repository | 443 | HTTPS | Pull desired state |
| ArgoCD | Kubernetes API | 443 | HTTPS | Apply manifests |
| GitLab CI | Container registry | 443 | HTTPS | Push container images |
| GitLab CI | ArgoCD API | 443 | HTTPS | Trigger deployment sync/checks |
| Promtail / Alloy | Loki | 3100 | HTTP | Push logs |
| Grafana | Loki | 3100 | HTTP | Query logs |
| Grafana | Prometheus | 9090 | HTTP | Query metrics |

### 4.4 Traffic volume baseline

Traffic volume was estimated from two local baseline sources:

- Locust request counts, used to estimate external request rate
- `docker stats` `net_io` deltas, used to estimate per-container transferred data during each run

These values are suitable for baseline planning and trend analysis, but they are not precise production traffic forecasts.

### 4.5 CI/CD and deployment traffic patterns

Its hard to have proper numbers here, because CI/CD pipeline traffic really depends on the developer, what he is pushing, what is being changed, what are logged.

But estimates for this is typically:

| Operation | Source -> Destination | Expected traffic volume | Comment |
|---|---|---|---|
| Git push / pipeline trigger | Developer / GitLab -> Git repository | 1-20MB | Mostly source code and metadata |
| Backend/frontend image push | GitLab CI -> Container Registry | 20-400MB | Typically tens to hundreds of MB per build depending on image size |
| Image pull during rollout | Kubernetes nodes -> Container Registry | 100-800MB | Each deployment requires image download to one or more nodes |
| ArgoCD manifest sync | ArgoCD -> Git repository | 1-5MB | Helm charts and manifests are small |
| ArgoCD apply operations | ArgoCD -> Kubernetes API | 1-5MB | Mostly control-plane configuration traffic |
| Metrics scraping | Prometheus -> app/exporters | 10-100KB/per scrape | Continuous background traffic |
| Log shipping | Promtail/Alloy -> Loki | 1-50MB/hour | Depends on log volume and retention |

These traffic patterns are important because deployment-related image transfers can be much larger than normal control-plane traffic, and log shipping can become a meaningful long-term network and storage cost driver.

#### External application traffic

| Test run | Duration | Total requests | Approx. requests/sec | Result |
|---|---:|---:|---:|---|
| 20 users | 120 s | 1215 | 10.1 | Stable |
| 50 users | 120 s | 2951 | 24.6 | Stable |
| 100 users | 120 s | 4856 | 40.5 attempted | Unstable, 1501 failures |

#### Approximate per-container network transfer during each run

| Test run | Container | Received | Sent | Total |
|---|---|---:|---:|---:|
| 20 users | Backend | 712.7 kB | 807.6 kB | 1520.3 kB |
| 20 users | PostgreSQL | 185.6 kB | 531.0 kB | 716.6 kB |
| 20 users | Prometheus | 231.0 kB | 9.2 kB | 240.2 kB |
| 50 users | Backend | 1807.0 kB | 2005.0 kB | 3812.0 kB |
| 50 users | PostgreSQL | 398.0 kB | 935.0 kB | 1333.0 kB |
| 50 users | Prometheus | 264.0 kB | 10.5 kB | 274.5 kB |
| 100 users | Backend | 2460.0 kB | 2370.0 kB | 4830.0 kB |
| 100 users | PostgreSQL | 899.0 kB | 980.0 kB | 1879.0 kB |
| 100 users | Prometheus | 240.0 kB | 10.1 kB | 250.1 kB |

#### Interpretation

- External request pressure rose from about `10.1 req/s` in the 20-user run to about `24.6 req/s` in the clean 50-user run.
- The 100-user run reached about `40.5 req/s` attempted, but this run was unstable and therefore should not be treated as a clean sustained baseline.
- Internal application traffic was concentrated mainly between the backend and PostgreSQL containers.
- Backend network transfer grew from about `1.5 MB` in the 20-user run to about `3.8 MB` in the 50-user run and about `4.8 MB` in the unstable 100-user run.
- PostgreSQL traffic also increased with concurrency, which supports the conclusion that database pressure becomes more relevant as load rises.
- Prometheus traffic stayed comparatively low and steady, which suggests that monitoring traffic is a constant overhead but not the dominant network consumer in these tests.
- Frontend container traffic was effectively negligible in these measurements because the Locust load test targeted backend API endpoints directly rather than simulating browser delivery of full frontend assets.

### 4.4 Dependency conclusions

- The business path is simple, but the target cloud platform adds several operational dependencies.
- The backend is the key bridge between public-facing traffic and private stateful data.
- PostgreSQL is the most critical stateful dependency.
- DNS, secrets, registry, and deployment tooling are all shared dependencies that must be designed carefully to avoid migration bottlenecks.

## 5. Infrastructure Overview and Requirements

This section describes the planned infrastructure for the cloud migration. The setup is split into three parts:

- `shared` for resources used by both environments
- `test` for validation and lower-cost experimentation
- `prod` for the actual production-ready setup

The goal is to keep `test` smaller and cheaper, while `prod` is designed with more reliability, scaling, and backup protection.

### 5.1 Detailed Server Specifications

The table below lists the main servers and managed components needed for the target setup. The exact AWS or GCP service names may differ, but the resource sizing logic stays mostly the same.

| Environment | Server / Component | Count | Compute | Storage | Network | Purpose |
|---|---|---:|---|---|---|---|
| Shared | GitLab VM (if self-managed) | 1 | 2 vCPU, 4 GB RAM | 50-100 GB SSD, encrypted | Public or VPN-only admin access, outbound internet required | Git hosting, CI coordination, runners if self-managed |
| Shared | Bastion / VPN VM | 1 | 1 vCPU, 1-2 GB RAM | 20 GB SSD, encrypted | Public entry point with restricted inbound access, connected to private network | Secure admin access to private infrastructure |
| Shared | Container Registry | 1 managed service | No dedicated VM | 10-50 GB to start, encrypted | Private service access, internet access for CI and cluster image pulls | Stores frontend and backend container images |
| Shared | DNS | 1 managed service | No dedicated VM | Managed zone records | Public DNS zone + private DNS zone | Public and internal name resolution |
| Test | Kubernetes control plane | 1 managed cluster | Provider-managed | Provider-managed | Private access preferred | Runs the test cluster control plane |
| Test | Main node | 1 | 2 vCPU, 4 GB RAM | 40-60 GB SSD, encrypted | Private subnet, outbound through NAT | Runs frontend and backend pods |
| Test | Monitoring node | 1 | 2 vCPU, 4 GB RAM | 60-100 GB SSD, encrypted | Private subnet, outbound through NAT | Runs Prometheus, Grafana, Loki, exporters |
| Test | Tools node | 1 | 2 vCPU, 2-4 GB RAM | 40-60 GB SSD, encrypted | Private subnet, outbound through NAT | Runs ArgoCD, External DNS, External Secrets, optional runners |
| Test | PostgreSQL | 1 managed DB | Small instance class, around 2 vCPU / 4 GB RAM | 20-50 GB SSD, encrypted, backups enabled | Private only, no public IP | Test database for the application |
| Test | Public load balancer | 1 managed service | No dedicated VM | Provider-managed | Public HTTPS entry point | Exposes frontend and any public endpoints |
| Test | Internal load balancer | 1 managed service | No dedicated VM | Provider-managed | Private only | Used for internal-only services if needed |
| Prod | Kubernetes control plane | 1 managed cluster | Provider-managed | Provider-managed | Private access preferred | Runs the production cluster control plane |
| Prod | Main nodes | 3 | 2-4 vCPU, 8 GB RAM each | 60-100 GB SSD each, encrypted | Private subnets across multiple AZs / zones | Runs frontend and backend with autoscaling |
| Prod | Monitoring nodes | 2 | 2-4 vCPU, 8 GB RAM each | 100-200 GB SSD each, encrypted | Private subnets across multiple AZs / zones | Runs Prometheus, Grafana, Loki, exporters |
| Prod | Tools nodes | 1-2 | 2 vCPU, 4 GB RAM each | 40-80 GB SSD each, encrypted | Private subnets across multiple AZs / zones | Runs ArgoCD, External DNS, External Secrets, tooling |
| Prod | PostgreSQL | 1 HA managed DB | Medium instance class, around 2-4 vCPU / 8-16 GB RAM | 100+ GB SSD, encrypted, PITR, daily backups | Private only, no public IP | Main production database |
| Prod | Public load balancer | 1 managed service | No dedicated VM | Provider-managed | Public HTTPS access | Frontend and public app traffic |
| Prod | Internal load balancer | 1 managed service | No dedicated VM | Provider-managed | Private only | Internal monitoring and service access |
| Prod | Object storage | 1 managed service | No dedicated VM | Encrypted object storage, log retention for one year | Private by default, controlled by IAM | Stores logs, artifacts, and retained data |

### 5.2 Networking Requirements

The network design should be private by default.

Main network requirements:

- Worker nodes must be placed in private subnets.
- PostgreSQL must stay private and must not have a public IP.
- Public IPs for cluster nodes, control plane, or database are not allowed.
- Public services such as the frontend must go through an external load balancer.
- Internal services such as Prometheus should use an internal load balancer if they need network access.
- Public DNS must be used for public endpoints.
- Private DNS must be used for internal-only services.
- Admin access should happen through a VPN, bastion host, or similar private access path.
- Outbound internet access from private nodes should go through NAT or equivalent.
- TLS/HTTPS must be used for public-facing traffic.

#### Main network flows

| Source | Destination | Access type | Why |
|---|---|---|---|
| User | Frontend | Public HTTPS | Main application access |
| Frontend | Backend | Internal cluster traffic or secured ingress path | API communication |
| Backend | PostgreSQL | Private only | Application data access |
| Prometheus | App/exporters | Private only | Metrics collection |
| Promtail/Alloy | Loki | Private only | Log shipping |
| ArgoCD | Kubernetes API | Private/internal | Deployment operations |
| GitLab CI | Registry / ArgoCD / cluster APIs | Controlled external access | Build and deployment workflow |

### 5.3 Kubernetes Infrastructure Specifications

The application is planned for a **managed standard Kubernetes cluster**. Auto-managed cluster modes like EKS Auto Mode, EKS Fargate, and GKE Autopilot are not used because the assignment specifically requires standard clusters and clearer node-group sizing.

#### Runtime requirements

| Item | Test | Prod |
|---|---|---|
| Cluster type | Managed standard Kubernetes cluster | Managed standard Kubernetes cluster |
| Cluster count | 1 | 1 |
| Node groups / pools | `main`, `monitoring`, `tools` | `main`, `monitoring`, `tools` |
| Main workloads | Frontend and backend pods | Frontend and backend pods |
| Monitoring workloads | Prometheus, Grafana, Loki, exporters | Prometheus, Grafana, Loki, exporters |
| Tools workloads | ArgoCD, External DNS, External Secrets, optional runners | ArgoCD, External DNS, External Secrets, optional runners |
| Autoscaling | Recommended | Required |
| HA | Not required | Required across multiple AZs / zones |

#### Node group purpose

| Node group | What runs there | Why it is separated |
|---|---|---|
| `main` | Frontend and backend | App traffic should not compete with monitoring or tooling |
| `monitoring` | Prometheus, Grafana, Loki, exporters | Monitoring has different CPU, memory, and storage behavior |
| `tools` | ArgoCD, External DNS, External Secrets, optional runners | Tooling should not interfere with application pods |

#### Why this cluster layout makes sense

- The backend is the first real pressure point based on the local tests, so the `main` node group is sized mainly around backend scaling.
- Monitoring is separated because Prometheus and Loki can slowly grow in storage and memory usage.
- Tooling is separated so deployment and control-plane helper services do not fight with the app for resources.
- `test` stays intentionally small to reduce cost.
- `prod` uses more nodes across multiple zones so the platform is more reliable.

### 5.4 Monitoring Requirements

The monitoring stack must be self-hosted and separated per environment.

Required monitoring components:

- Grafana
- Prometheus
- Prometheus Postgres exporter
- Loki
- Promtail or Grafana Alloy

Requirements:

- `test` and `prod` must each have their own monitoring stack
- managed monitoring services are not allowed
- metrics must be kept for one month
- logs must be kept for one year

#### Monitoring resource expectations

| Component | Main resource need | Why |
|---|---|---|
| Prometheus | Memory + disk | Stores and queries time-series metrics |
| Grafana | Low to medium memory | Dashboards and queries |
| Loki | Disk + memory | Stores logs and serves queries |
| Promtail / Alloy | Low compute | Ships logs to Loki |
| Postgres exporter | Very low compute | Exposes PostgreSQL metrics |

### 5.5 Storage Requirements

Storage has to cover database data, logs, metrics, container images, and backups.

#### Main storage requirements

| Storage area | Requirement |
|---|---|
| PostgreSQL | Managed PostgreSQL service with encrypted storage |
| Test DB backups | Kept smaller, based on practical need |
| Prod DB backups | Daily backups, PITR enabled, 30 retained backups |
| Prod DB logs | 7 days retention |
| Metrics storage | One month retention |
| Log storage | One year retention |
| Container images | Private container registry |
| All storage | Encryption at rest required |

#### Storage behavior by component

| Component | Storage type | Notes |
|---|---|---|
| PostgreSQL | Persistent managed block storage | Most critical stateful storage |
| Prometheus | Persistent volume | Needed for metric retention |
| Loki | Persistent volume or object-backed storage | Needed for long log retention |
| GitLab VM (if self-managed) | Persistent SSD | Holds repos, CI metadata, and possibly artifacts |
| Container Registry | Managed image storage | Grows over time unless lifecycle cleanup is used |
| Object storage | Managed object storage | Good for long retention and lower-cost archive-style storage |

### 5.6 Sizing Summary

The final sizing logic is based on the local performance baseline and the target production requirement.

- The frontend is lightweight and does not need large compute resources.
- The backend is the first component that showed real scaling pressure, so compute sizing is mainly driven by backend behavior.
- PostgreSQL stays moderate at lower traffic, but it becomes more important as concurrency rises, so production uses a managed HA database.
- Monitoring must be separated because Prometheus and Loki add real storage and memory overhead.
- The production environment needs more nodes, HA, and stronger backup settings, while test is allowed to stay small and cheaper.

## 6. Cloud Security Mechanisms

### 6.1 Main security concerns

- accidentally exposing the database publicly
- over-permissioned IAM roles
- secrets stored in Git or plain env files
- public Kubernetes nodes or admin endpoints
- poor cost visibility from missing tags and ownership controls

### 6.2 Required controls

| Area | Control |
|---|---|
| IAM | Least privilege for humans and workloads |
| Secrets | Cloud-native secret manager plus External Secrets |
| Network | Private subnets, private DB, controlled ingress |
| Encryption in transit | TLS for public endpoints |
| Encryption at rest | Enabled on DB, buckets, registry, and persistent volumes |
| Cluster access | Private endpoint, VPN, or jump path |
| Auditing | CloudTrail / cloud audit logs plus tagging |

## 7. High Availability (HA): Benefits and Drawbacks

### 7.1 Benefits

- higher resilience if an AZ fails
- safer deployments with multiple replicas
- lower risk of total service outage
- managed database failover becomes possible

### 7.2 Drawbacks

- higher monthly cost
- more operational complexity
- more infrastructure to configure and validate

### 7.3 Recommended decision

| Environment | HA recommendation | Reason |
|---|---|---|
| Test | No full HA | Keep cost low and use for validation |
| Production | Yes | The target is real user traffic and higher reliability expectations |
