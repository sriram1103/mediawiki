#!/bin/bash -xe

err(){
    echo "$*"
    exit 1
}

[[ $# -ne 3 ]] && err "Not enough arguments"
region=$1
yum install -y amazon-efs-utils
yum install -y jq
file_system_id_1=$(aws ssm get-parameter --name "/mediawiki/ec2/nfs" --region $region | jq -rc '.Parameter.Value')
wikiDNS=$(aws ssm get-parameter --name "/mediawiki/elb/dns" --region $region | jq -rc '.Parameter.Value')
dbHost=$(aws ssm get-parameter --name "/mediawiki/db/host" --region $region | jq -rc '.Parameter.Value')
dbName=$(aws ssm get-parameter --name "/mediawiki/db/name" --region $region | jq -rc '.Parameter.Value')
dbUser=$(aws ssm get-parameter --name "/mediawiki/db/user" --region $region | jq -rc '.Parameter.Value')
dbPass=$(aws secretsmanager get-secret-value --secret-id  dbPassword --region $region | jq -rc '.SecretString')
[[ -z $file_system_id_1 || -z $dbHost || -z $dbName || \
    -z $dbUser || -z $dbPass || -z $wikiDNS ]] && err "Unable to get param"

efs_mount_point_1=/efs
mkdir -p "${efs_mount_point_1}"
test -f "/sbin/mount.efs" && printf "\n${file_system_id_1}:/ ${efs_mount_point_1} efs tls,_netdev\n" >> /etc/fstab || printf "\n${file_system_id_1}.efs.$region.amazonaws.com:/ ${efs_mount_point_1} nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0\n" >> /etc/fstab
test -f "/sbin/mount.efs" && printf "\n[client-info]\nsource=liw\n" >> /etc/amazon/efs/efs-utils.conf
retryCnt=15; waitTime=30; while true; do mount -a -t efs,nfs4 defaults; if [ $? = 0 ] || [ $retryCnt -lt 1 ]; then echo File system mounted successfully; break; fi; echo File system not available, retrying to mount.; ((retryCnt--)); sleep $waitTime; done;

mount | grep efs || err "Unable to mount nfs"

mkdir -p "${efs_mount_point_1}"/{images,conf,extensions,skins}
amazon-linux-extras install ansible2 -y || err "Failed to install ansible"
cd /var/tmp/tw/ansible
ansible-playbook -i localhost, -c local main.yml -e wiki_version=$2 -e wiki_fullversion=$3 -e dbHost=${dbHost} -e dbUser=${dbUser} -e dbPass=${dbPass} -e dbName=${dbName} -e wikihost=${wikiDNS}