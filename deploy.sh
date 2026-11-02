#!/bin/bash
set -e 
source ./BashFunctions.sh

echo "Nginx deployment script with k3s"

if [ ! -d ".terraform" ]; then
  echo "Initializing Terraform..."
  terraform init
fi

read_replicas "Minimum replicas: " 1
min_replicas="$REPLY"

read_replicas "Maximum replicas: " "$min_replicas"
max_replicas="$REPLY"
Port
echo "Creating deployment with $min_replicas to $max_replicas replicas on port $external_port..."


Terraform_setup "$min_replicas" "$max_replicas" "$external_port"
echo "Deployment completed successfully."
kubectl get pods -n webb -l app=webb


Test_nginx "$external_port"

echo "You can access it at http://localhost:"$external_port" and its fully deployed with $min_replicas to $max_replicas replicas."
