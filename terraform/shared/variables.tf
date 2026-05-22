variable "aws_region" {
  type        = string
  description = "AWS region for shared resources."
  default     = "eu-central-1"
}

variable "project_name" {
  type        = string
  description = "Project name prefix used for resource naming."
  default     = "voyager"
}

variable "tags" {
  type        = map(string)
  description = "Common resource tags."
  default = {
    project = "voyager"
    managed = "terraform"
  }
}
