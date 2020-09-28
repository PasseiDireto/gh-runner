#!/bin/bash

if [ -n "${GITHUB_REPOSITORY}" ]
then
    auth_url="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPOSITORY}/actions/runners/registration-token"
    registration_url = "https://github.com/${GITHUB_OWNER}/${GITHUB_REPOSITORY}"
    
else
    auth_url="https://api.github.com/orgs/${GITHUB_OWNER}/actions/runners/registration-token"
    registration_url= "https://github.com/${GITHUB_OWNER}"
fi

echo "Requesting registration URL at '${auth_url}'"

payload=$(curl -sX POST -H "Authorization: token ${GITHUB_PERSONAL_TOKEN}" ${auth_url})
export RUNNER_TOKEN=$(echo $payload | jq .token --raw-output)

./config.sh \
    --name ${RUNNER_NAME}-$(hostname) \
    --token ${RUNNER_TOKEN} \
    --url $registration_url \
    --work ${RUNNER_WORKDIR} \
    --unattended \
    --replace

remove() {
    ./config.sh remove --unattended --token "${RUNNER_TOKEN}"
}

trap 'remove; exit 130' INT
trap 'remove; exit 143' TERM

./run.sh "$*" &

wait $!