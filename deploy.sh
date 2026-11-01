#!/bin/bash
set -e

echo "Nginx deployment script with k3s"

read -rp "Enter the number of replicas for the application: " replicas

if ! [[ "$replicas" =~ ^[0-9]+$ ]]; then
  echo "Error: Please enter a valid number for replicas."
  exit 1
fi

echo "Creating deployment with $replicas replicas..."

terraform plan -var="replicas=$replicas" -out=tfplan
terraform apply tfplan

echo "Deployment completed successfully."
kubectl get pods -l app=webb
