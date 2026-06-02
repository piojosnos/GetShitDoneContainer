#!/bin/bash
# Usage: ./cc-up.sh <project_name> <host_path>

export PROJECT_NAME=$1
export PROJECT_PATH=$2

docker-compose -p "cc_${PROJECT_NAME}" up -d
