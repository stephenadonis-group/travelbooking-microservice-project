variable "vpc-name" {
  description = "Name of the VPC network"
  type        = string
}

variable "subnet-name" {
  description = "Name of the subnet"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "vpc-cidr" {
  description = "CIDR range for the subnet"
  type        = string
}
