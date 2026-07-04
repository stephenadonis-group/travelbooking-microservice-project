variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "tags" {
  description = "Common Tags"
  type        = map(string)
}