# Nginx med Terraform och K3s

GitHub: [EliasTerraform](https://github.com/ettan5/EliasTerraform)

## Mål

Målet med projektet är att använda Terraform för att skapa och hantera en Nginx-webbserver i ett Kubernetes-kluster med K3s. Konfigurationen beskriver vilka resurser som ska finnas, och ett Bash-skript kör Terraform med ett valt antal repliker. Bash används i stället för PowerShell enligt överenskommelse med läraren.

## Verktyg och förutsättningar

Projektet använder Terraform, Kubernetes-providern från HashiCorp, K3s, kubectl och Bash. K3s-klustret måste redan vara installerat och igång. Terraform installerar inte själva klustret.

För att köra projektet behövs:

- Terraform 1.0 eller senare.
- Bash och Git.
- Ett fungerande K3s-kluster och kubectl.
- Läsbehörighet till `/etc/rancher/k3s/k3s.yaml`, som används av Terraform.
- En fungerande kubectl-konfiguration för samma kluster.
- Metrics Server för CPU-mätningar till den automatiska skalningen.
- Stöd för tjänster av typen LoadBalancer i klustret.

## Metod och uppbyggnad

Terraform använder providern `hashicorp/kubernetes` med versionskravet `~> 3.0`. Följande fyra resurser skapas:

| Resurs | Namn | Uppgift |
| --- | --- | --- |
| Namespace | `webb` | Samlar projektets resurser i ett eget namespace. |
| Deployment | `local-nginx` | Kör containrar med imagen `nginx:latest`. |
| Service | `local-nginx-service` | Tar emot trafik på port 8081 och skickar den till port 80 i poddarna. |
| Horizontal Pod Autoscaler | `local-nginx-hpa` | Anpassar antalet repliker mellan 1 och 5 utifrån CPU-belastningen. |

Varje container begär 250m CPU och 256Mi minne. Gränserna är 500m CPU och 512Mi minne. Autoscalern har ett CPU-mål på 50 procent av begärd CPU.

Variabeln `replicas` anger antalet repliker i deployment-konfigurationen och har standardvärdet 1. När autoscalern arbetar kan den ändra det faktiska antalet repliker.

### Projektets filer

| Fil | Innehåll |
| --- | --- |
| `main.tf` | Provider, Kubernetes-resurser och outputs. |
| `variables.tf` | Variabeln `replicas`. |
| `deploy.sh` | Läser in antal repliker och kör Terraform. |
| `.terraform.lock.hcl` | Låser vald provider-version och dess kontrollsummor. |
| `README.md` | Beskriver projektet och hur det körs. |

Terraform skapar även state-filer som håller reda på resurserna. Dessa behövs för fortsatt hantering av miljön.

## Installation och körning

Klona projektet och gå till projektmappen:

```bash
git clone https://github.com/ettan5/EliasTerraform.git
cd EliasTerraform
```

Kontrollera att kubectl kan nå rätt kluster:

```bash
kubectl get nodes
```

Kontrollera sökvägen till kubeconfig i `main.tf`. Den är inställd på `/etc/rancher/k3s/k3s.yaml` och kan behöva ändras om miljön ser annorlunda ut.

Initiera och validera Terraform:

```bash
terraform init
terraform validate
```

Kör Bash-skriptet från projektmappen:

```bash
bash deploy.sh
```

Ange exempelvis `1` när skriptet frågar efter antal repliker. Skriptet kontrollerar att inmatningen består av siffror, sparar en plan i `tfplan` och genomför sedan planen direkt. `set -e` gör att skriptet avbryts om ett kommando misslyckas. Den nuvarande kontrollen begränsar inte värdet till autoscalerns intervall 1–5.

För att granska planen separat före genomförandet kan Terraform köras manuellt:

```bash
terraform plan -var="replicas=1" -out=tfplan
terraform apply tfplan
```

## Verifiering och resultat

Kontrollera deployment, poddar, service och autoscaler:

```bash
kubectl get deployment,pods,svc,hpa -n webb
kubectl rollout status deployment/local-nginx -n webb
terraform output
```

Terraform har tre outputs: `namespace`, `deployment_name` och `repicas`. Det sista namnet är stavat så i den nuvarande koden.

Vid kontroll den 2 november 2026 gick `terraform validate` igenom. Deploymenten hade en tillgänglig replik och en Nginx-pod var i status `Running`. Servicen hade en extern IP-adress och autoscalern rapporterade CPU-mätvärden med intervallet 1–5 repliker. Skalning under belastning har inte verifierats.

Visa servicens aktuella externa adress:

```bash
kubectl get svc local-nginx-service -n webb
```

Webbservern kan testas på `http://<EXTERNAL-IP>:8081` om adressen är nåbar från datorn. Ett alternativ är port-forwarding:

```bash
kubectl port-forward -n webb svc/local-nginx-service 8081:8081
```

Kör sedan följande i en annan terminal:

```bash
curl -I http://localhost:8081
```

HTTP-testet ovan är ett manuellt verifieringssteg och ingick inte i den dokumenterade kontrollen. Bash-skriptets avslutande `kubectl get pods` saknar för närvarande `-n webb`, så det visar bara rätt poddar om kubectl redan använder detta namespace.

## Reflektion och fortsatt utveckling

Projektet visar hur Terraform kan beskriva flera resurser som tillsammans kör en webbserver. Namespace, deployment, service och autoscaler har olika roller och kopplas ihop genom namn och etiketter. Bash-skriptet samlar planering och deployment i ett körflöde.

En viktig skillnad är att giltig Terraform-kod och en körande pod inte i sig bevisar att webbsidan går att nå. Därför behöver verifieringen även kontrollera HTTP-svaret. Nästa förbättring är att lägga till detta i Bash-skriptet tillsammans med funktioner, en loop som väntar på webbservern och tydligare felmeddelanden.

Det finns också två saker att förbättra i Terraform-konfigurationen. En bestämd Nginx-version skulle göra miljön mer förutsägbar än `latest`. Terraform och autoscalern kan dessutom båda ändra antalet repliker, vilket behöver hanteras så att en senare Terraform-körning inte återställer autoscalerns val oavsiktligt.

Projektet använder Kubernetes-providern. Kursmaterialet anger providern `local`, så den delen behöver kompletteras eller godkännas separat av läraren. Godkännandet att använda Bash gäller ersättningen för PowerShell.
