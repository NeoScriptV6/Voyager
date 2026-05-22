variable "aws_region" {
  type        = string
  description = "AWS region for the prod environment."
  default     = "eu-central-1"
}

variable "project_name" {
  type    = string
  default = "voyager"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "cluster_name" {
  type    = string
  default = "voyager-prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.20.101.0/24", "10.20.102.0/24", "10.20.103.0/24"]
}

variable "availability_zones" {
  type    = list(string)
  default = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "domain_name" {
  type    = string
  default = "example.com"
}

variable "tags" {
  type = map(string)
  default = {
    project     = "voyager"
    environment = "prod"
    managed     = "terraform"
  }
}
