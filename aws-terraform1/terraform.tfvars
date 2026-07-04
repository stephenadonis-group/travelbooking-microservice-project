##############################################
# AWS
##############################################
aws_region = "us-east-1"

##############################################
# VPC
##############################################
vpc_name   = "travelbooking-vpc"
vpc_cidr   = "10.0.0.0/16"
public_subnets = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]
private_subnets = [
  "10.0.10.0/24",
  "10.0.20.0/24"
]

##############################################
# EKS
##############################################
cluster_name     = "travelbooking-eks"
cluster_version  = "1.30"
node_group_name  = "travelbooking-workers"
instance_type    = "t3.medium"
desired_size     = 2
min_size         = 2
max_size         = 5
disk_size        = 50

##############################################
# ALB
##############################################
alb_name = "travelbooking-alb"

##############################################
# Amazon ECR
##############################################
ecr_repositories = [
  "frontend",
  "user-service",
  "search-service",
  "booking-service",
  "payment-service",
  "notification-service"
]

##############################################
# Tags
##############################################
tags = {
  Project     = "TravelBooking"
  Owner       = "Stephen"
  Environment = "Production"
}
elastic_ip_name = "travelbooking-eip"