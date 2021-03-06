aws_region          = "ap-south-1"
application         = "mediawiki"
environment         = "dev"
user                = "sriram"
tfc_version         = "0.1.0"
key_name            = "mediawiki"
instance_role       = "ec2-wiki-role"
vpc_name            = "media-vpc"
vpc_cidr_block      = "172.32.0.0/16"
vpc_subnet_size     = 20
rds_dbname          = "wikidatabase"
rds_dbuser          = "wiki"
rds_dbpass          = "wiki12345"
rds_instance_class  = "db.t2.micro"
wiki_majorVersion   = "1.35"
wiki_minorVersion   = "1.35.0"
wiki_stackName      = "wikistack"