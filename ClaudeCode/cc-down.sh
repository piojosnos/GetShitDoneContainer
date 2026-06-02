#!/bin/bash
# Usage: ./cc-down.sh <project_name> <host_path>

export PROJECT_NAME=$1

docker-compose -p "cc_${PROJECT_NAME}" down -v