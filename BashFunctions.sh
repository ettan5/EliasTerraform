## Fråga efter minimum och spara svaret direkt i min_replicas.
read_min_replicas() {
  while true; do
    read -rp "Minimum replicas: " min_replicas || return 1

    # Första siffran måste vara 1–9. Sedan får fler siffror följa.
    # Till exempel godkänns 1, 5 och 20, men inte 0, -1 eller text.
    if ! [[ "$min_replicas" =~ ^[1-9][0-9]*$ ]]; then
      echo "Error: Enter a positive whole number."
      continue
    fi

    break
  done
}

## Fråga efter maximum och jämför med minimum från första frågan.
read_max_replicas() {
  local minimum="$1"

  while true; do
    read -rp "Maximum replicas: " max_replicas || return 1

    if ! [[ "$max_replicas" =~ ^[1-9][0-9]*$ ]]; then
      echo "Error: Enter a positive whole number."
      continue
    fi

    if (( max_replicas < minimum )); then
      echo "Error: Maximum must be at least $minimum."
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
  if ! terraform apply tfplan; then
    echo "Error: Terraform apply failed."
    return 1
  fi
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

Programs_install() {
  local program

  # Gå igenom varje verktygsnamn som skickats från arrayen i deploy.sh.
  for program in "$@"; do
    if command -v "$program" > /dev/null 2>&1; then
      printf '\033[32m%s is installed\033[0m\n' "$program"
    else
      printf '\033[31m%s is not installed\033[0m\n' "$program"
      return 1
    fi
  done
}
