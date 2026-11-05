#!/bin/bash
set -e 
source ./BashFunctions.sh

echo "Nginx deployment script with k3s"
programs=("terraform" "k3s")
Programs_install "${programs[@]}"

if [ ! -d ".terraform" ]; then
  echo "Initializing Terraform..."
  terraform init
fi

read_min_replicas
read_max_replicas "$min_replicas"
Port
echo "Creating deployment with $min_replicas to $max_replicas replicas on port $external_port..."


Terraform_setup "$min_replicas" "$max_replicas" "$external_port"

kubectl get pods -n webb -l app=webb


Test_nginx "$external_port"

mkdir -p logs
echo "Nginx responded on port $external_port. HPA range: $min_replicas to $max_replicas replicas." >> logs/deploy.log

echo "Deployment completed successfully. Result saved in logs/deploy.log."
echo "You can access it at http://localhost:"$external_port" and its fully deployed with $min_replicas to $max_replicas replicas."
