##############################################
# AWS Provider
##############################################
variable "aws_region" {
  description = "AWS Region"
  type        = string
}

##############################################
# VPC
##############################################
variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "public_subnets" {
  description = "Public subnet CIDRs"
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet CIDRs"
  type        = list(string)
}

##############################################
# EKS
##############################################
variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes Version"
  type        = string
}

variable "node_group_name" {
  description = "Managed Node Group"
  type        = string
}

variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
}

variable "desired_size" {
  description = "Desired Node Count"
  type        = number
}

variable "min_size" {
  description = "Minimum Node Count"
  type        = number
}

variable "max_size" {
  description = "Maximum Node Count"
  type        = number
}

variable "disk_size" {
  description = "Node Disk Size"
  type        = number
}

##############################################
# ECR
##############################################
variable "ecr_repositories" {
  description = "Repositories to create"
  type        = list(string)
}

##############################################
# ALB
##############################################
variable "alb_name" {
  description = "Application Load Balancer Name"
  type        = string
}

##############################################
# Tags
##############################################
variable "elastic_ip_name" {
  description = "Elastic IP Name"
  type        = string
}

variable "tags" {
  description = "Common Tags"
  type        = map(string)
  default = {
    Project     = "TravelBooking"
    Terraform   = "true"
    Environment = "Production"
  }
}