#!/bin/bash

set -e  # Exit on error
set -o pipefail  # Catch pipeline errors

# Define Variables
VIRTUAL_ENV=".venv"
DATA_MANIFEST_FILE="./dataManifest.json"
PIPELINE_EXECUTION_FILE="ml_pipeline/pipelineExecutionArn"
PIPELINE_JSON_OUTPUT="pipelineExecution.json"

# Verify Environment Variables
if [[ -z "$SAGEMAKER_PIPELINE_ROLE_ARN" || -z "$SAGEMAKER_PROJECT_NAME" || -z "$AWS_REGION" || -z "$SAGEMAKER_ARTIFACT_BUCKET" ]]; then
  echo "Error: Required environment variables are not set."
  echo "Ensure SAGEMAKER_PIPELINE_ROLE_ARN, SAGEMAKER_PROJECT_NAME, AWS_REGION, and SAGEMAKER_ARTIFACT_BUCKET are defined."
  exit 1
fi

# Verify Data Manifest File
if [[ ! -f "$DATA_MANIFEST_FILE" ]]; then
  echo "Error: Data manifest file $DATA_MANIFEST_FILE not found."
  exit 1
fi

DATA_MANIFEST=$(cat "$DATA_MANIFEST_FILE")

pushd ml_pipeline

# Create Virtual Environment
echo "Setting up virtual environment..."
if [[ ! -d "$VIRTUAL_ENV" ]]; then
  virtualenv -p python3 "$VIRTUAL_ENV"
fi
. "$VIRTUAL_ENV/bin/activate"

# Install Dependencies
echo "Installing dependencies..."
pip install -r requirements.txt
pip install sagemaker==2.232.0

# Run Pipeline
echo "Starting SageMaker Pipeline Execution..."
export PYTHONUNBUFFERED=TRUE

python run_pipeline.py \
  --module-name pipeline \
  --role-arn "$SAGEMAKER_PIPELINE_ROLE_ARN" \
  --tags "[{\"Key\":\"sagemaker:project-name\", \"Value\":\"${SAGEMAKER_PROJECT_NAME}\"}]" \
  --kwargs "{\"region\":\"${AWS_REGION}\",\"role\":\"${SAGEMAKER_PIPELINE_ROLE_ARN}\",\"default_bucket\":\"${SAGEMAKER_ARTIFACT_BUCKET}\",\"pipeline_name\":\"${SAGEMAKER_PROJECT_NAME}\",\"model_package_group_name\":\"${SAGEMAKER_PROJECT_NAME}\",\"base_job_prefix\":\"${SAGEMAKER_PROJECT_NAME}\"}"

echo "Pipeline execution script completed."

# Deactivate Virtual Environment
deactivate

popd

# Handle Pipeline Execution Results
if [[ -f "$PIPELINE_EXECUTION_FILE" ]]; then
  MODEL_PACKAGE_NAME=$(cat "$PIPELINE_EXECUTION_FILE")
  echo "Pipeline execution completed. Model Package ARN: $MODEL_PACKAGE_NAME"
  echo "{\"arn\": \"$MODEL_PACKAGE_NAME\"}" > "$PIPELINE_JSON_OUTPUT"
else
  echo "Error: Pipeline execution failed. $PIPELINE_EXECUTION_FILE not found."
  exit 1
fi

echo "Pipeline execution results saved to $PIPELINE_JSON_OUTPUT."
