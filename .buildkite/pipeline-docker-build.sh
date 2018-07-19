#!/bin/bash
set -euo pipefail

rm -rf $(basename "$AIRFLOW_PLUGIN_REPO" ".${AIRFLOW_PLUGIN_REPO##*.}")
git clone ${AIRFLOW_PLUGIN_REPO}

if [[ "$1" = "dev" ]]; then
  docker build -t ${DEV_ECR_URI}:${BUILDKITE_COMMIT} .

  docker tag ${DEV_ECR_URI}:${BUILDKITE_COMMIT} ${DEV_ECR_URI}:${BUILDKITE_BRANCH}

  docker push ${DEV_ECR_URI}:${BUILDKITE_COMMIT}
  docker push ${DEV_ECR_URI}:${BUILDKITE_BRANCH}
fi

if [[ "$1" = "production" ]]; then
  docker pull ${DEV_ECR_URI}:${BUILDKITE_COMMIT}

  docker tag ${DEV_ECR_URI}:${BUILDKITE_COMMIT} ${PROD_ECR_URI}:${BUILDKITE_COMMIT}
  docker tag ${DEV_ECR_URI}:${BUILDKITE_COMMIT} ${PROD_ECR_URI}:${BUILDKITE_BRANCH}

  docker push ${PROD_ECR_URI}:${BUILDKITE_COMMIT}
  docker push ${PROD_ECR_URI}:${BUILDKITE_BRANCH}
fi
