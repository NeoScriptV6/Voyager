provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_route53_zone" "root_public" {
  name         = var.domain_name
  private_zone = false
}

data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  name_prefix                 = "${var.project_name}-${var.environment}"
  public_zone_name            = "${var.environment}-public.${var.domain_name}"
  private_zone_name           = "${var.environment}-private.${var.domain_name}"
  db_private_host             = "db.${local.private_zone_name}"
  backend_secret_name         = "${var.project_name}/${var.environment}/backend"
  public_certificate_domains  = ["*.${local.public_zone_name}", "www.${var.domain_name}"]
  private_certificate_domains = ["*.${local.private_zone_name}"]
  oidc_provider_host          = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  common_tags                 = merge(var.tags, { project = var.project_name, environment = var.environment })
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = local.common_tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.13.1"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access           = false
  cluster_endpoint_private_access          = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = aws_iam_role.ebs_csi.arn
    }
  }

  eks_managed_node_groups = {
    main = {
      instance_types = ["t3.large"]
      min_size       = 2
      max_size       = 5
      desired_size   = 3
      labels = {
        workload = "main"
      }
    }
    tools = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      labels = {
        workload = "tools"
      }
      taints = {
        dedicated = {
          key    = "workload"
          value  = "tools"
          effect = "NO_SCHEDULE"
        }
      }
    }
    monitoring = {
      instance_types = ["t3.large"]
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      labels = {
        workload = "monitoring"
      }
      taints = {
        dedicated = {
          key    = "workload"
          value  = "monitoring"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  tags = local.common_tags
}

resource "aws_security_group" "bastion" {
  name        = "${local.name_prefix}-bastion"
  description = "SSM bastion for cluster troubleshooting"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-bastion"
    component = "bastion"
  })
}

resource "aws_security_group_rule" "cluster_from_bastion" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = aws_security_group.bastion.id
  description              = "Allow bastion access to the private EKS API"
}

resource "aws_iam_role" "bastion" {
  name = "${local.name_prefix}-bastion"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${local.name_prefix}-bastion"
  role = aws_iam_role.bastion.name
}

resource "aws_instance" "bastion" {
  ami                  = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type        = "t3.nano"
  subnet_id            = module.vpc.private_subnets[0]
  iam_instance_profile = aws_iam_instance_profile.bastion.name
  vpc_security_group_ids = [
    aws_security_group.bastion.id
  ]

  metadata_options {
    http_tokens = "required"
  }

  user_data = <<-EOT
    #!/bin/bash
    dnf install -y awscli
    curl -Lo /usr/local/bin/kubectl https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl
    chmod +x /usr/local/bin/kubectl
  EOT

  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-bastion"
    component = "bastion"
  })
}

resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db"
  description = "Database access only from EKS worker nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    component = "database"
  })
}

resource "random_password" "postgres" {
  length  = 24
  special = false
}

resource "random_password" "jwt_key" {
  length  = 48
  special = false
}

resource "aws_db_subnet_group" "postgres" {
  name       = "${local.name_prefix}-postgres"
  subnet_ids = module.vpc.private_subnets

  tags = merge(local.common_tags, {
    component = "database"
  })
}

resource "aws_db_instance" "postgres" {
  identifier                 = "${local.name_prefix}-postgres"
  engine                     = "postgres"
  engine_version             = "16"
  instance_class             = "db.t4g.small"
  allocated_storage          = 50
  max_allocated_storage      = 200
  storage_type               = "gp3"
  db_name                    = "postgres"
  username                   = "postgres"
  password                   = random_password.postgres.result
  storage_encrypted          = true
  publicly_accessible        = false
  multi_az                   = true
  skip_final_snapshot        = false
  final_snapshot_identifier  = "${local.name_prefix}-final"
  deletion_protection        = true
  backup_retention_period    = 30
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true
  db_subnet_group_name       = aws_db_subnet_group.postgres.name
  vpc_security_group_ids     = [aws_security_group.db.id]
  enabled_cloudwatch_logs_exports = [
    "postgresql"
  ]

  tags = merge(local.common_tags, {
    component = "database"
  })
}

resource "aws_route53_zone" "public" {
  name = local.public_zone_name

  tags = merge(local.common_tags, {
    visibility = "public"
  })
}

resource "aws_route53_zone" "private" {
  name = local.private_zone_name

  vpc {
    vpc_id = module.vpc.vpc_id
  }

  tags = merge(local.common_tags, {
    visibility = "private"
  })
}

resource "aws_route53_record" "public_delegation" {
  zone_id = data.aws_route53_zone.root_public.zone_id
  name    = "${var.environment}-public"
  type    = "NS"
  ttl     = 300
  records = aws_route53_zone.public.name_servers
}

resource "aws_route53_record" "db" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "db"
  type    = "CNAME"
  ttl     = 300
  records = [aws_db_instance.postgres.address]
}

resource "aws_secretsmanager_secret" "backend" {
  name = local.backend_secret_name

  tags = merge(local.common_tags, {
    component = "application-secret"
  })
}

resource "aws_secretsmanager_secret_version" "backend" {
  secret_id = aws_secretsmanager_secret.backend.id
  secret_string = jsonencode({
    username = "postgres"
    password = random_password.postgres.result
    database = "postgres"
    host     = local.db_private_host
    jwt_key  = random_password.jwt_key.result
  })
}

resource "aws_s3_bucket" "logs" {
  bucket = "${local.name_prefix}-logs"

  tags = merge(local.common_tags, {
    component = "logs"
  })
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_acm_certificate" "public" {
  domain_name               = local.public_certificate_domains[0]
  subject_alternative_names = [local.public_certificate_domains[1]]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    component  = "public-cert"
    visibility = "public"
  })
}

resource "aws_route53_record" "public_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.public.domain_validation_options :
    dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
      zone_id = endswith(dvo.domain_name, local.public_zone_name) ? aws_route53_zone.public.zone_id : data.aws_route53_zone.root_public.zone_id
    }
  }

  zone_id = each.value.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "public" {
  certificate_arn         = aws_acm_certificate.public.arn
  validation_record_fqdns = [for record in aws_route53_record.public_cert_validation : record.fqdn]
}

resource "tls_private_key" "private" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "private" {
  private_key_pem = tls_private_key.private.private_key_pem

  subject {
    common_name  = local.private_certificate_domains[0]
    organization = "Voyager"
  }

  dns_names = local.private_certificate_domains

  validity_period_hours = 8760
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

resource "aws_acm_certificate" "private" {
  private_key      = tls_private_key.private.private_key_pem
  certificate_body = tls_self_signed_cert.private.cert_pem

  tags = merge(local.common_tags, {
    component  = "private-cert"
    visibility = "private"
  })
}

data "aws_iam_policy_document" "external_dns_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:sub"
      values   = ["system:serviceaccount:external-dns:external-dns"]
    }
  }
}

resource "aws_iam_role" "external_dns" {
  name               = "${local.name_prefix}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "external_dns" {
  statement {
    actions = [
      "route53:ChangeResourceRecordSets"
    ]
    resources = [
      aws_route53_zone.public.arn,
      aws_route53_zone.private.arn
    ]
  }

  statement {
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "external_dns" {
  name   = "${local.name_prefix}-external-dns"
  policy = data.aws_iam_policy_document.external_dns.json
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}

data "aws_iam_policy_document" "external_secrets_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:sub"
      values   = ["system:serviceaccount:external-secrets:external-secrets"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${local.name_prefix}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = [
      aws_secretsmanager_secret.backend.arn
    ]
  }
}

resource "aws_iam_policy" "external_secrets" {
  name   = "${local.name_prefix}-external-secrets"
  policy = data.aws_iam_policy_document.external_secrets.json
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}

data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${local.name_prefix}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

data "aws_iam_policy_document" "load_balancer_controller_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:sub"
      values   = ["system:serviceaccount:aws-load-balancer-controller:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "load_balancer_controller" {
  name               = "${local.name_prefix}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.load_balancer_controller_assume.json
  tags               = local.common_tags
}

resource "aws_iam_policy" "load_balancer_controller" {
  name   = "${local.name_prefix}-aws-load-balancer-controller"
  policy = file("${path.module}/../policies/aws-load-balancer-controller-policy.json")
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  role       = aws_iam_role.load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}

data "aws_iam_policy_document" "grafana_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:sub"
      values   = ["system:serviceaccount:monitoring:grafana"]
    }
  }
}

resource "aws_iam_role" "grafana" {
  name               = "${local.name_prefix}-grafana"
  assume_role_policy = data.aws_iam_policy_document.grafana_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "grafana_cloudwatch" {
  role       = aws_iam_role.grafana.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

data "aws_iam_policy_document" "loki_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:sub"
      values   = ["system:serviceaccount:monitoring:loki"]
    }
  }
}

resource "aws_iam_role" "loki" {
  name               = "${local.name_prefix}-loki"
  assume_role_policy = data.aws_iam_policy_document.loki_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "loki" {
  statement {
    actions = [
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.logs.arn]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["${aws_s3_bucket.logs.arn}/*"]
  }
}

resource "aws_iam_policy" "loki" {
  name   = "${local.name_prefix}-loki"
  policy = data.aws_iam_policy_document.loki.json
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "loki" {
  role       = aws_iam_role.loki.name
  policy_arn = aws_iam_policy.loki.arn
}
