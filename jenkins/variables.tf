variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "subnet_cidr_block" {
  description = "The CIDR block for the subnet"
  type        = string
}

variable "avail_zone" {
  description = "The availability zone to deploy the resources"
  type        = string
}

variable "env_prefix" {
  description = "The prefix to use for environment-specific resource naming"
  type        = string
}

variable "instance_type" {
  description = "The type of instance to be used"
  type        = string
}

variable "key_name" {
  description = "The name of the SSH key pair"
  type        = string
}
