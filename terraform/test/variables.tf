variable "aws_region" {
  type        = string
  description = "AWS region for the test environment."
  default     = "eu-central-1"
}

variable "project_name" {
  type    = string
  default = "voyager"
}

variable "environment" {
  type    = string
  default = "test"
}

variable "cluster_name" {
  type    = string
  default = "voyager-test"
}

variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.10.101.0/24", "10.10.102.0/24", "10.10.103.0/24"]
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
  type        = string
  description = "Root domain you control."
  default     = "example.com"
}

variable "tags" {
  type = map(string)
  default = {
    project     = "voyager"
    environment = "test"
    managed     = "terraform"
  }
}
