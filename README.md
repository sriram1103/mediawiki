## MediaWiki

To deploy execute:

```bash
$ terraform init
$ terraform plan
$ terraform apply
```
----

Directory | Contents
----------|-----------
ansible   | playbook code to update or install wiki
cft       | cloudformation template to setup wiki instances
tf        | terraform code to create the environment
scripts   | scripts to perform stack create/update
logs      | saved the logs during test

----

* Run terraform tfvars file to deploy the updated infrastructure
* Update the version (major,minor) and run terraform apply to update the wiki alone
* To scale application update the ASG parameters in template.yml
* ASG update will do the rolling update with extra ec2 instance

After terraform deploy, the wiki home page will be available hitting the ELB

http://ELB_DNS_NAME/mediawiki

----

To destroy execute:

```bash
$ terraform destroy
```