# Risk Assessment & Management Plan

> **Project:** Cloud Cartographer  
> **Target application:** React frontend + Go backend + PostgreSQL  
> **Target platform:** Kubernetes, managed PostgreSQL, GitOps, self-hosted monitoring

## 1. Purpose

This document identifies the main risks in moving the application from a local Docker Compose setup to a cloud-based Kubernetes platform.

The goal is to:

- identify the biggest technical and operational risks
- reduce the chance of those risks happening
- define what to do if they still happen

## 2. Assessment Method

Each risk is rated using:

- **Probability:** Low, Medium, or High
- **Impact:** Low, Medium, or High
- **Priority:** overall importance based on probability and impact

## 3. Risk Register

| Risk | Why it matters | Probability | Impact | Priority | Main mitigation | Response if it happens |
|---|---|---|---|---|---|---|
| Cost overrun | Kubernetes, NAT, load balancers, storage, and monitoring can increase monthly cost quickly | High | High | High | Budgets, billing alerts, tagging, small test environment, lifecycle policies | Review billing, shrink non-critical resources, reduce retention, right-size services |
| Public exposure / network misconfiguration | A public database or overly open cluster access would be a major security failure | Medium | High | High | Private subnets, private DB, restricted ingress, separate public/private DNS, VPN for admin access | Remove exposure immediately, rotate credentials, review logs and permissions |
| Secrets leakage | DB credentials, JWT secrets, and deployment credentials must not end up in Git or plain files | Medium | High | High | Use cloud secret manager + External Secrets, least-privilege IAM, never commit secrets | Rotate secrets, revoke access, inspect logs, fix the workflow |
| Backend instability under load | Local testing already showed backend pressure and instability at higher concurrency | High | High | High | Horizontal scaling, autoscaling rules, better performance testing, review auth and registration paths | Scale backend, inspect latency/errors, check DB pressure, optimize slow paths |
| Database failure or data loss | PostgreSQL is the most critical stateful component | Medium | High | High | Managed PostgreSQL, backups, PITR, private access, restore testing | Fail over or restore from backup, verify integrity, investigate root cause |
| Failed deployment | CI/CD, Helm, ArgoCD, and Kubernetes add several points of failure | Medium | High | High | Test-before-prod, manual prod approval, readiness checks, version-controlled manifests | Stop rollout, roll back, verify services, inspect CI/CD and ArgoCD logs |
| Monitoring blind spots | Incidents are harder to detect and debug without working metrics and logs | Medium | Medium | Medium | Deploy Prometheus, Grafana, Loki, exporters, dashboards, and alerts early | Use pod logs and cluster events first, restore missing observability components |
| CI/CD misuse or excessive privileges | A compromised pipeline token could affect multiple environments | Medium | High | High | Separate test/prod credentials, least privilege, protected branches, manual prod approval | Revoke tokens, pause deployments, rotate secrets, review pipeline history |
| Environment drift | If test and prod differ too much, test results stop being trustworthy | Medium | Medium | Medium | Use Terraform and Helm as source of truth, avoid manual changes, document differences | Compare configs, remove manual drift, align versions, retest |
| Team operational complexity | Terraform, Kubernetes, ArgoCD, monitoring, and secrets management create a real learning curve | High | Medium | High | Clear documentation, simple deployment path, runbooks, avoid unnecessary tooling | Simplify the platform, improve documentation, rehearse recovery in test |

## 4. Highest-Priority Risks

The highest-priority risks for this project are:

1. cost overruns
2. network/security misconfiguration
3. backend instability under load
4. database failure or data loss
5. deployment failure

These are highest priority because they directly affect:

- service availability
- security
- data protection
- long-term sustainability of the platform

## 5. Preventive Controls

### 5.1 Architecture controls

- Keep Kubernetes nodes private.
- Keep PostgreSQL private.
- Use separate environments for shared, test, and production.
- Scale frontend and backend horizontally instead of relying on one large node.

### 5.2 Security controls

- Use least-privilege IAM.
- Store secrets in a cloud secret manager.
- Use TLS on public endpoints.
- Protect CI/CD credentials and deployment permissions.

### 5.3 Operational controls

- Deploy to test before production.
- Require manual approval before production deployment.
- Use dashboards and alerts from the start.
- Test backup and restore procedures.

### 5.4 Financial controls

- Create budgets and billing alerts early.
- Tag all resources by environment and owner.
- Apply retention and lifecycle rules for logs and images.
- Shut down non-essential test resources when possible.

## 6. Incident Response Principles

If a serious incident happens, the response order should be:

1. contain the issue
2. protect data and credentials
3. restore minimum service
4. identify root cause
5. improve the platform so the same problem is less likely

## 7. Conclusion

The migration is feasible, but it introduces real operational risk. The main concerns are not only application bugs, but also cloud cost, security mistakes, broken deployments, and database protection.

The safest approach is to:

- keep the platform private by default
- use managed PostgreSQL
- deploy through GitOps
- monitor the system early
- treat test as the proving ground before production

If these controls are followed, the remaining risks become manageable.
