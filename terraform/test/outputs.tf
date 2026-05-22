output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "db_address" {
  value = aws_db_instance.postgres.address
}

output "db_private_host" {
  value = local.db_private_host
}

output "backend_secret_name" {
  value = aws_secretsmanager_secret.backend.name
}

output "public_zone_name" {
  value = aws_route53_zone.public.name
}

output "private_zone_name" {
  value = aws_route53_zone.private.name
}

output "public_zone_id" {
  value = aws_route53_zone.public.zone_id
}

output "private_zone_id" {
  value = aws_route53_zone.private.zone_id
}

output "logs_bucket_name" {
  value = aws_s3_bucket.logs.id
}

output "public_certificate_arn" {
  value = aws_acm_certificate_validation.public.certificate_arn
}

output "private_certificate_arn" {
  value = aws_acm_certificate.private.arn
}

output "external_dns_role_arn" {
  value = aws_iam_role.external_dns.arn
}

output "external_secrets_role_arn" {
  value = aws_iam_role.external_secrets.arn
}

output "load_balancer_controller_role_arn" {
  value = aws_iam_role.load_balancer_controller.arn
}

output "grafana_role_arn" {
  value = aws_iam_role.grafana.arn
}

output "loki_role_arn" {
  value = aws_iam_role.loki.arn
}

output "bastion_instance_id" {
  value = aws_instance.bastion.id
}
