variable "vpc_config" {

  description = "Contains the configuration for the VPC. More especially, the CIDR block and the name of the VPC."

  type = object({
    cidr_block = string
    name       = string
  })

  validation {
    condition     = can(cidrnetmask(var.vpc_config.cidr_block))
    error_message = "The cidr_block config option must contain a valid CIDR block."
  }
}

variable "subnet_config" {

  description = <<EOF
  Accepts a map of objects that define the configuration for the subnets. Each object must contain the following attributes:
  - cidr_block: The CIDR block for the subnet.
  - public: A boolean value that indicates whether the subnet is public or private. Defaults to false.
  - az: The availability zone in which the subnet will be created. This is required.
  The map key is used to identify the subnet and must be unique.
  EOF

  type = map(object({
    cidr_block = string
    public     = optional(bool, false)
    az         = string
  }))

  validation {
    condition = alltrue([
      for config in values(var.subnet_config) : can(cidrnetmask(config.cidr_block))
    ])
    error_message = "The cidr_block config option must contain a valid CIDR block."
  }
}