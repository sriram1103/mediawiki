terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  required_version = ">= 0.13.0"
/*
  # Uncomment to store the state file in s3  
  backend "s3" {
    region  = "ap-south-1"
    bucket  = "tf-mediawiki-s3"
    encrypt = true
    key     = "ap-south-1/dev/terraform.tfstate"
  }
*/
}

provider "aws" {
  region = var.aws_region
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
}

module "key-pair" {
  source     = "terraform-aws-modules/key-pair/aws"
  version    = "0.5.0"
  key_name   = "${var.key_name}"
  public_key = tls_private_key.this.public_key_openssh
}

resource "aws_iam_role" "ec2_role" {
  name = var.instance_role

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_role_policy" "ec2_role_policy" {
  name = "ec2_role_policy"
  role = aws_iam_role.ec2_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*",
        "ssm:PutParameter",
        "ssm:DescribeParameters",
        "ssm:GetParametersByPath",
        "ssm:GetParameters",
        "ssm:GetParameter",
        "secretsmanager:GetRandomPassword",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:UntagResource",
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds",
        "secretsmanager:ListSecrets",
        "secretsmanager:TagResource",
        "rds:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

locals {
  tags = {
    Application        = var.application
    Region             = var.aws_region
    Owner              = var.user
    Version            = var.tfc_version
    Environment        = var.environment
  }
  subnet_newbit        = "${var.vpc_subnet_size}" - split("/","${var.vpc_cidr_block}")[1]
  private_subnet_start = 1 * "${length(var.availability_zones)}"
  public_subnet_start  = 2 * "${length(var.availability_zones)}"  
}

module "vpc" {
  source                 = "terraform-aws-modules/vpc/aws"
  version                = "2.50.0"
  name                   = var.vpc_name
  cidr                   = var.vpc_cidr_block
  azs                    = var.availability_zones
  tags                   = local.tags
  private_subnet_suffix  = "application"
  private_subnets        = [ for _num in range("${local.private_subnet_start}"): cidrsubnet("${var.vpc_cidr_block}", "${local.subnet_newbit}", _num)]
  public_subnet_suffix   = "nat"
  public_subnets         = [ for _num in range("${local.private_subnet_start}","${local.public_subnet_start}"): cidrsubnet("${var.vpc_cidr_block}", "${local.subnet_newbit}", _num)]
  enable_dns_hostnames   = true
  create_vpc             = true
  enable_s3_endpoint     = false
  create_igw             = true
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true
}

module "rds" {
  source                  = "terraform-aws-modules/rds/aws"
  version                 = "2.18.0"
  family                  = "mysql5.7"
  major_engine_version    = "5.7"
  engine                  = "mysql"
  engine_version          = "5.7.24"
  instance_class          = var.rds_instance_class
  allocated_storage       = 5
  storage_encrypted       = false

  identifier              = var.rds_dbname
  name                    = var.rds_dbname
  username                = var.rds_dbuser
  password                = var.rds_dbpass
  port                    = "3306"

  backup_retention_period = 0
  tags                    = local.tags
  vpc_security_group_ids  = [module.vpc.default_security_group_id]
  subnet_ids              = module.vpc.private_subnets
  deletion_protection     = false
  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:00-06:00"
}

resource "aws_ssm_parameter" "stack_name" {
  name        = "/mediawiki/cf/stack_name"
  description = "${var.application} stack name"
  type        = "String"
  value       = var.wiki_stackName

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = "aws cloudformation delete-stack --stack-name ${self.value}"
  }  
}

resource "aws_ssm_parameter" "key_name" {
  name        = "/mediawiki/ec2/key_name"
  description = "${var.application} key name"
  type        = "String"
  value       = module.key-pair.this_key_pair_key_name
}

resource "aws_ssm_parameter" "sg_name" {
  name        = "/mediawiki/ec2/sg_name"
  description = "${var.application} sg name"
  type        = "String"
  value       = module.vpc.default_security_group_id
}

resource "aws_ssm_parameter" "nfs_id" {
  name        = "/mediawiki/ec2/nfs"
  description = "${var.application} nfs id"
  type        = "String"
  value       = aws_efs_file_system.efs.id
}

resource "aws_ssm_parameter" "dbHost" {
  name        = "/mediawiki/db/host"
  description = "${var.application} db host name"
  type        = "String"
  value       = module.rds.this_db_instance_address
}


resource "aws_ssm_parameter" "dbUser" {
  name        = "/mediawiki/db/user"
  description = "${var.application} db user"
  type        = "String"
  value       = var.rds_dbuser
}

resource "aws_ssm_parameter" "dbName" {
  name        = "/mediawiki/db/name"
  description = "${var.application} db name"
  type        = "String"
  value       = var.rds_dbname
}


resource "aws_ssm_parameter" "lbDNS" {
  name        = "/mediawiki/elb/dns"
  description = "${var.application} elb dns name"
  type        = "String"
  value       = aws_lb.wiki-elb.dns_name
}

resource "aws_secretsmanager_secret" "dbPass" {
  name = "dbPassword"
}


resource "aws_secretsmanager_secret_version" "dbPass" {
  secret_id     = aws_secretsmanager_secret.dbPass.id
  secret_string = module.rds.this_db_instance_password
}

resource "aws_efs_file_system" "efs" {
  creation_token = "wiki"

  tags = local.tags
}

resource "aws_efs_mount_target" "efs_mount" {
  count           = length(var.availability_zones) > 0 ? length(var.availability_zones) : 0
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = element(module.vpc.private_subnets, count.index)
  security_groups = [module.vpc.default_security_group_id]
}

resource "aws_security_group_rule" "http-80" {
  security_group_id = module.vpc.default_security_group_id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ssh" {
  security_group_id = module.vpc.default_security_group_id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "rds" {
  security_group_id = module.vpc.default_security_group_id
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "TCP"
  self              = true
}

resource "aws_security_group_rule" "nfs" {
  security_group_id = module.vpc.default_security_group_id
  type              = "ingress"
  from_port         = 2049
  to_port           = 2049
  protocol          = "TCP"
  self              = true
}

resource "aws_lb_target_group" "alb-tg" {
  name         = "${var.application}-app-tg"
  port         = 80
  protocol     = "HTTP"
  vpc_id       = module.vpc.vpc_id
}


resource "aws_lb" "wiki-elb" {
  name               = "${var.application}-wiki-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.vpc.default_security_group_id]
  subnets            = module.vpc.public_subnets
  tags               = local.tags
}

resource "aws_lb_listener" "wiki-lsnr" {
  load_balancer_arn = aws_lb.wiki-elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-tg.arn
  }
}

resource "null_resource" "stackAction" {
  provisioner "local-exec" {
    command     = "../scripts/create_update_stack.sh ${var.wiki_majorVersion} ${var.wiki_minorVersion} ${var.wiki_stackName} ${aws_ssm_parameter.dbHost.value}"
    interpreter = ["/bin/bash", "-c"]
  }

  triggers = {
    always_run = "${timestamp()}"
  }  
}