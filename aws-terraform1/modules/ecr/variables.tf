variable "repositories" {
  description = "List of ECR repositories to create"
  type        = list(string)
}

variable "tags" {
  description = "Common Tags"
  type        = map(string)
}