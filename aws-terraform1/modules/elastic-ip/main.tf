resource "aws_eip" "travelbooking" {
  domain = "vpc"

  tags = {
    Name        = var.name
    Project     = "TravelBooking"
    Environment = "Production"
  }
}