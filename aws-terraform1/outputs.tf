##############################################
# Networking
##############################################
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "elastic_ip" {
  value       = module.elastic-ip.elastic_ip
  description = "Elastic IP Address"
}

output "public_subnets" {
  value = module.vpc.public_subnet_ids
}

output "private_subnets" {
  value = module.vpc.private_subnet_ids
}

##############################################
# Amazon EKS
##############################################
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate" {
  value     = module.eks.cluster_certificate
  sensitive = true
}

output "kubectl_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

##############################################
# Amazon ECR
##############################################
output "repositories" {
  value = module.ecr.repository_urls
}


##############################################
# IAM
##############################################
output "cluster_role" {
  value = module.iam.cluster_role_arn
}

output "node_role" {
  value = module.iam.node_role_arn
}
