output "private_key_pem" {
  description = "Private Key"
  value       = tls_private_key.this.private_key_pem
}

output "private_key_pem_id" {
  description = "Private Key ID"
  value       = module.key-pair.this_key_pair_key_name
}


output "target_group_arn" {
  description = "ASG Target Group ARN"
  value       = aws_lb_target_group.alb-tg.arn
}

output "sg_id" {
  description = "Security Group ID"
  value       = module.vpc.default_security_group_id
}

output "subnet_id" {
  description = "Pub Subnet IDS"
  value       = join("\\,",module.vpc.public_subnets)
}

output "stack_name" {
    value = var.wiki_stackName
}

output "instance_role" {
  description = "EC2 instance Role"
  value       = aws_iam_instance_profile.ec2_profile.name
}
