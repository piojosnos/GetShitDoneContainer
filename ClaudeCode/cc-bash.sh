#!/bin/bash
# Usage: ./cc-up.sh <project_name> <host_path>

export PROJECT_NAME=$1

docker exec -it cc_gsd_${PROJECT_NAME} /bin/bash
