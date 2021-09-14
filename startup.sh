#!/bin/bash

echo "Starting supervisor (Docker)"
sudo service docker start

if [ -n "${GITHUB_REPOSITORY}" ]
then
  auth_url="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPOSITORY}/actions/runners/registration-token"
  registration_url="https://github.com/${GITHUB_OWNER}/${GITHUB_REPOSITORY}"
else
  auth_url="https://api.github.com/orgs/${GITHUB_OWNER}/actions/runners/registration-token"
  registration_url="https://github.com/${GITHUB_OWNER}"
fi

generate_token() {
  payload=$(curl -sX POST -H "Authorization: token ${GITHUB_PERSONAL_TOKEN}" "${auth_url}")
  runner_token=$(echo "${payload}" | jq .token --raw-output)

  if [ "${runner_token}" == "null" ]
  then
    echo "${payload}"
    exit 1
  fi

  echo "${runner_token}"
}

remove_runner() {
  ./config.sh remove --unattended --token "$(generate_token)"
}

service docker status
runner_id=${RUNNER_NAME}_$(openssl rand -hex 6)
echo "Registering runner ${runner_id}"

./config.sh \
  --name "${runner_id}" \
  --labels "${RUNNER_LABELS}" \
  --token "$(generate_token)" \
  --url "${registration_url}" \
  --unattended \
  --replace \
  --ephemeral

trap 'remove_runner; exit 130' SIGINT
trap 'remove_runner; exit 143' SIGTERM


./run.sh "$*"