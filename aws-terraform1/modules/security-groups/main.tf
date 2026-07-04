# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.vpc_id}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "travelbooking-alb-sg"
  })
}

# EKS Cluster Security Group (basic)
resource "aws_security_group" "eks_cluster" {
  name        = "${var.vpc_id}-eks-cluster-sg"
  description = "Security group for EKS Cluster"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "travelbooking-eks-cluster-sg"
  })
}

# EKS Nodes Security Group
resource "aws_security_group" "eks_nodes" {
  name        = "${var.vpc_id}-eks-nodes-sg"
  description = "Security group for EKS Worker Nodes"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "travelbooking-eks-nodes-sg"
  })
}