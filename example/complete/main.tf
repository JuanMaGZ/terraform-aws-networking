module "vpc" {
  source = "./modules/networking"

  vpc_config = {
    cidr_block = "10.0.0.0/16"
    name       = "your_vpc_name"
  }

  subnet_config = {
    subnet_1 = {
      cidr_block = "10.0.0.0/24"
      # Public subnets are inidicated by setting the public flag to true
      public     = true
      az         = "us-east-2a"
    }

    subnet_2 = {
      cidr_block = "10.0.1.0/24"
      az         = "us-east-2b"
    }
  }
}