# 1. Output of the vpc id
# 2. Output of the public subnets - subnet_key => {subnet_id, availability_zone}
# 3. Output of the private subnets - subnet_key => {subnet_id, availability_zone}

locals {
  output_public_subnets = {
    for key in keys(local.public_subnets) : key => {
      subnet_id         = aws_subnet.this[key].id
      availability_zone = aws_subnet.this[key].availability_zone
    }
  }

  output_private_subnets = {
    for key in keys(local.private_subnets) : key => {
      subnet_id         = aws_subnet.this[key].id
      availability_zone = aws_subnet.this[key].availability_zone
    }
  }
}

output "vpc_id" {
  description = "The AWS ID from the created VPC"
  value       = aws_vpc.this.id
}


output "public_subnets" {
  description = "The ID and the availability zone of public subnets."
  value       = local.output_public_subnets
}

output "private_subnets" {
  description = "The ID and the availability zone of private subnets."
  value       = local.output_private_subnets
}

output "elastic_ip_dns" {
  description = "The DNS of the Elastic IP created for the NAT Gateway."
  value       = length(aws_eip.this) > 0 ? aws_eip.this[0].public_dns : null
}

output "elastic_ip" {
  description = "The Elastic IP created for the NAT Gateway."
  value       = length(aws_eip.this) > 0 ? aws_eip.this[0].public_ip : null
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway (if created)."
  value       = length(aws_nat_gateway.this) > 0 ? aws_nat_gateway.this[0].id : null
}
