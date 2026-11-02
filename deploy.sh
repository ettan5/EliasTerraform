#!/bin/bash
set -e

echo "Nginx deployment script with k3s"

if [ ! -d ".terraform" ]; then
  echo "Initializing Terraform..."
  terraform init
fi

read -rp "Enter the number of minimum replicas for the application: " min_replicas
if ! [[ "$min_replicas" =~ ^[0-9]+$ ]]; then
  echo "Error: Please enter a valid number for minimum replicas."
  exit 1
fi

read -rp "Enter the number of maximum replicas for the application: " max_replicas
if ! [[ "$max_replicas" =~ ^[0-9]+$ ]]; then
  echo "Error: Please enter a valid number for maximum replicas."
  exit 1
fi

echo "Creating deployment with $min_replicas to $max_replicas replicas..."

terraform plan -var="min_replicas=$min_replicas" -var="max_replicas=$max_replicas" -out=tfplan
terraform apply tfplan

echo "Deployment completed successfully."
kubectl get pods -l app=webb
