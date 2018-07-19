#!/bin/bash
set -euo pipefail

git clone ${AIRFLOW_PLUGIN_REPO}

if [[ "$1" = "dev" ]]; then
  docker build -t ${DEV_ECR_URI}:${BUILDKITE_COMMIT} .

  docker tag ${DEV_ECR_URI}:${BUILDKITE_COMMIT} ${DEV_ECR_URI}:${BUILDKITE_BRANCH}

  docker ${DEV_ECR_URI}:${BUILDKITE_COMMIT}
  docker ${DEV_ECR_URI}:${BUILDKITE_BRANCH}
fi

if [[ "$1" = "production" ]]; then
  docker pull ${DEV_ECR_URI}:${BUILDKITE_COMMIT}

  docker tag ${DEV_ECR_URI}:${BUILDKITE_COMMIT} ${PROD_ECR_URI}:${BUILDKITE_COMMIT}
  docker tag ${DEV_ECR_URI}:${BUILDKITE_COMMIT} ${PROD_ECR_URI}:${BUILDKITE_BRANCH}

  docker push ${PROD_ECR_URI}:${BUILDKITE_COMMIT}
  docker push ${PROD_ECR_URI}:${BUILDKITE_BRANCH}
fi
