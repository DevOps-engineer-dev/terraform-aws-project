output "alb_dns_name" {
  description = "Public DNS name of the load balancer - open this in a browser"
  value       = aws_lb.main.dns_name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "private_subnet_ids" {
  value = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "web_instance_ids" {
  value = [aws_instance.web_a.id, aws_instance.web_b.id]
}
