#!/bin/bash
#set -x

err() {
    echo "$*"
    exit 1
}

[[ $# -lt 3 ]] && err "not enough arguments"
myPath="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
tfPath="$( cd $myPath/../tf >/dev/null 2>&1; pwd -P)"
cftPath="$( cd $myPath/../cft >/dev/null 2>&1; pwd -P)"

majorVersion=$1
minorVersion=$2
stackName=$3

cd $tfPath
echo "Getting stack params"
sshKeyName=$(terraform output -json | jq -rc '.private_key_pem_id.value')
sgName=$(terraform output -json | jq -rc '.sg_id.value')
tgName=$(terraform output -json | jq -rc '.target_group_arn.value')
profileName=$(terraform output -json | jq -rc '.instance_role.value')
subnetsName=$(terraform output -json | jq -rc '.subnet_id.value')

[[ -z $sshKeyName || -z $sgName || -z $tgName || -z $profileName || -z $subnetsName ]] && \
    err "Unable to get stack param"

cd $cftPath
template=$(cat template.yml)
if ! aws cloudformation describe-stacks --stack-name $stackName >/dev/null 2>&1 
then
    echo "Creating Stack"
    aws cloudformation create-stack --stack-name $stackName --parameters ParameterKey=AppFullVersion,ParameterValue=$minorVersion \
        ParameterKey=AppVersion,ParameterValue=$majorVersion \
        ParameterKey=SSHKey,ParameterValue=$sshKeyName \
        ParameterKey=SecurityGroup,ParameterValue=$sgName \
        ParameterKey=TargetGroupArn,ParameterValue=$tgName \
        ParameterKey=InstanceProfile,ParameterValue=$profileName \
        ParameterKey=Subnets,ParameterValue="$subnetsName" \
        --template-body "${template}"
else
    echo "Updating Stack"
    aws cloudformation update-stack --stack-name  $stackName --parameters ParameterKey=AppFullVersion,ParameterValue=$minorVersion \
        ParameterKey=AppVersion,ParameterValue=$majorVersion \
        ParameterKey=SSHKey,ParameterValue=$sshKeyName \
        ParameterKey=SecurityGroup,ParameterValue=$sgName \
        ParameterKey=TargetGroupArn,ParameterValue=$tgName \
        ParameterKey=InstanceProfile,ParameterValue=$profileName \
        ParameterKey=Subnets,ParameterValue="$subnetsName" \
        --template-body "${template}" 
fi
