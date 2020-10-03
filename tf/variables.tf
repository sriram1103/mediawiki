variable "aws_region" {
    default = "ap-south-1"
}

variable "application" {}

variable "environment" {}

variable "tfc_version" {}

variable "user" {}

variable "vpc_name" {}

variable "availability_zones" {
    type = list
    default = ["ap-south-1a","ap-south-1b"]
}

variable "vpc_cidr_block" {}

variable "vpc_subnet_size" {}

variable "rds_dbname" {}

variable "rds_dbuser" {}

variable "rds_dbpass" {}

variable "rds_instance_class" {}

variable "key_name" {}

variable "instance_role" {}

variable "wiki_majorVersion" {}

variable "wiki_minorVersion" {}

variable "wiki_stackName" {}