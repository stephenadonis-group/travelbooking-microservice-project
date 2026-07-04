output "elastic_ip" {
  description = "Elastic IP Address"
  value       = aws_eip.travelbooking.public_ip
}

output "allocation_id" {
  description = "Elastic IP Allocation ID"
  value       = aws_eip.travelbooking.id
}