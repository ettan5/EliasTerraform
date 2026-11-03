## read_replicas function prompts the user for a number of replicas and validates the input
read_replicas() {
  local prompt="$1"
  local minimum="$2"

  while true; do
    read -rp "$prompt" REPLY || return 1

    if ! [[ "$REPLY" =~ ^[1-9][0-9]*$ ]]; then
      echo "Error: Enter a positive whole number."
      continue
    fi

    if (( REPLY < minimum )); then
      echo "Error: Enter at least $minimum."
      continue
    fi

    break
  done
}
## Prompt for the external port number and validate it
Port(){
while true; do
    read -rp "Enter the external port for the LoadBalancer service (default: 8081): " external_port
    external_port="${external_port:-8081}"

    if ! [[ "$external_port" =~ ^[0-9]+$ ]] || (( external_port < 8080 || external_port > 9000 )); then
      echo "Error: Please enter a valid port number between 8080 and 9000."
      continue
    fi

    break
  done
}
## Set up Terraform and apply the configuration
Terraform_setup() {
  local min_replicas="$1"
  local max_replicas="$2"
  local external_port="$3"
  terraform plan -var="min_replicas=$min_replicas" -var="max_replicas=$max_replicas" -var="external_port=$external_port" -out=tfplan
  terraform apply tfplan
}
## Test Nginx deployment with curl to ensure it's running correctly
Test_nginx() {
  
  local external_port="$1"
  for i in {1..10}; do
    if curl -s http://localhost:$external_port | grep -q "Welcome to nginx!"; then
      echo "Nginx is running successfully."
      return 0
    else
      echo "Waiting for Nginx to be ready... (Attempt $i/10)"
      sleep 5
    fi
    
  done
  
echo "Nginx did not respond as expected after 10 attempts."
return 1
}
