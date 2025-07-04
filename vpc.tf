locals {
  public_subnets = {
    for key, config in var.subnet_config : key => config if config.public
  }

  private_subnets = {
    for key, config in var.subnet_config : key => config if !config.public
  }

  public_subnet_keys      = keys(local.public_subnets)
  first_public_subnet_key = length(local.public_subnet_keys) > 0 ? local.public_subnet_keys[0] : null
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_config.cidr_block
  enable_dns_support   = var.vpc_config.enable_dns_support
  enable_dns_hostnames = var.vpc_config.enable_dns_hostnames

  tags = {
    Name = var.vpc_config.name
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.vpc_config.enable_flow_logs ? 1 : 0
  name  = "/aws/vpc/flow-logs/${aws_vpc.this.id}"
  retention_in_days = 14
}

resource "aws_iam_role" "flow_log_role" {
  count = var.vpc_config.enable_flow_logs ? 1 : 0
  name  = "vpc-flow-logs-role-${aws_vpc.this.id}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "flow_log_policy" {
  count = var.vpc_config.enable_flow_logs ? 1 : 0
  name  = "vpc-flow-logs-policy-${aws_vpc.this.id}"
  role  = aws_iam_role.flow_log_role[0].name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "this" {
  count                = var.vpc_config.enable_flow_logs ? 1 : 0
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  iam_role_arn         = aws_iam_role.flow_log_role[0].arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.this.id

  tags = {
    Name = "vpc-flow-log-${aws_vpc.this.id}"
  }
}


resource "aws_subnet" "this" {
  for_each                = var.subnet_config
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.az
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = each.value.public == true ? each.value.map_public_ip_on_launch : false

  tags = {
    Name   = each.key
    Access = each.value.public ? "Public" : "Private"
  }

  lifecycle {
    precondition {
      condition     = contains(data.aws_availability_zones.available.names, each.value.az)
      error_message = <<-EOT
      The AZ "${each.value.az}" provided for the subnet "${each.key}" is invalid.

      The applied AWS region "${data.aws_availability_zones.available.id}" supports the following AZs:
      [${join(", ", data.aws_availability_zones.available.names)}]
      EOT
    }
  }
}

resource "aws_internet_gateway" "this" {
  count  = length(local.public_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id
}

resource "aws_route_table" "public_rtb" {
  count  = length(local.public_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }
  tags = {
    Name = "public-rtb"
  }
}

resource "aws_route_table_association" "public" {
  for_each = local.public_subnets

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.public_rtb[0].id
}

resource "aws_eip" "this" {
  count  = var.vpc_config.enable_nat_gateway && length(local.public_subnets) > 0 ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "this" {
  count         = length(aws_eip.this) > 0 ? 1 : 0
  allocation_id = aws_eip.this[0].id
  subnet_id     = aws_subnet.this[local.first_public_subnet_key].id

  tags = {
    Name = "nat-gw"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "private_rtb" {
  count  = var.vpc_config.enable_nat_gateway && length(local.private_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[0].id
  }

  tags = {
    Name = "private-rtb"
  }
}

resource "aws_route_table_association" "private" {
  for_each = var.vpc_config.enable_nat_gateway ? local.private_subnets : {}

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.private_rtb[0].id
}


