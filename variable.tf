variable "region" {
  description = "please provide a region information"
  type        = string
  default     = "us-east-1"
}

#cidr for VPC
variable "vpc_cidr" {
  description = "provide vpc_cidr"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["us-east-1a", "us-east-1b", "us-east-1c", ]
}

# cidr for public  subnets
variable "cidr_public_subnets" {
  description = "cidr for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24", ]
}


#cidr for PRIVATE subnets
variable "cidr_private_subnets" {
  description = "cidr for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", ]
}


variable "private_key" {
  description = "private key location"
  type        = string
  default     = "/home/ec2-user/.ssh/id_rsa"
}

variable "public_key" {
  description = "public key location"
  type        = string
  default     = "/home/ec2-user/.ssh/id_rsa.pub"
}

variable "instance_username" {
  description = "user to ssh to remote host"
  type        = string
  default     = "ec2-user"
}


variable "hosted-zone-id" {
  description = "provide zone id"
  type        = string
  default     = "Z0680016PA4LTHI66LBC"
}

variable "domain-name" {
  description = "provide domain name"
  type        = string
  default     = "hawaii2021.click"
}

