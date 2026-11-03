# Nginx med Terraform och K3s

GitHub: [EliasTerraform](https://github.com/ettan5/EliasTerraform)

## Mål

Målet är att automatisera driftsättning av en Nginx-webbserver med Terraform och Bash i ett lokalt K3s-kluster. Skriptet frågar efter minsta och största antal poddar samt vilken port webbservern ska nås på. Efter driftsättningen kontrollerar det att Nginx svarar.

Bash används i stället för PowerShell och Kubernetes-providern i stället för local-providern enligt överenskommelse med läraren.

## Förutsättningar

Projektet körs på en Linux-dator med ett redan installerat K3s-kluster. Terraform installerar inte själva klustret.

Följande behövs:

- Bash, Terraform, Git, kubectl, curl och grep.
- Terraform som uppfyller konfigurationens krav på minst version 1.0 och den valda providerns egna krav.
- Läsbehörighet till `/etc/rancher/k3s/k3s.yaml`.
- kubectl konfigurerat för samma kluster som Terraform.
- Metrics Server för autoskalarens CPU-mätningar.
- En fungerande lastbalanserare, till exempel K3s ServiceLB, och en ledig port.

Webbkontrollen använder `localhost`. Den är därför skriven för att köras direkt på den laptop där K3s körs och där Servicen går att nå via localhost. Det är inte en generell garanti för alla Kubernetes-kluster.

## Projektets filer

| Fil | Innehåll |
| --- | --- |
| `main.tf` | Provider, namespace, deployment, Service, autoskalare och outputs. |
| `variables.tf` | Variabler för minimum, maximum och extern port. |
| `deploy.sh` | Läser in funktionsfilen och kör stegen i ordning. |
| `BashFunctions.sh` | Funktioner för inmatning, portval, Terraform och webbkontroll. |
| `.terraform.lock.hcl` | Låser providerversionen och dess kontrollsummor. |
| `README.md` | Beskriver hur projektet fungerar och körs. |

Alla kommandon nedan körs från projektmappen. Det behövs eftersom skriptet läser in `./BashFunctions.sh` och kör Terraform i den aktuella katalogen.

## Hur det fungerar

Terraform använder `hashicorp/kubernetes` med versionskravet `~> 3.0`. Kubernetes-resurserna för appen samlas i namespacet `webb`.

| Resurs | Namn | Uppgift |
| --- | --- | --- |
| Namespace | `webb` | Samlar appens resurser. |
| Deployment | `local-nginx` | Startar med en replik och beskriver poddarnas innehåll. |
| Service | `local-nginx-service` | Tar emot trafik på vald port och skickar vidare till port 80 i poddarna. |
| Horizontal Pod Autoscaler, HPA | `local-nginx-hpa` | Ändrar antalet repliker inom valt minimum och maximum utifrån CPU-belastningen. |

Poddarna får etiketten `app=webb`. Deploymentens och Servicens selektorer matchar den etiketten. Servicen kan då skicka trafik till de poddar som är redo, även när poddar ersätts.

Varje pod innehåller en container med imagen `nginx:latest`. Varje container begär `250m` CPU och `256Mi` minne. Dess gränser är `500m` CPU och `512Mi` minne. `1000m` motsvarar en CPU och `Mi` betyder mebibyte.

HPA har ett CPU-mål på 50 procent av requests, alltså `125m` per pod i genomsnitt. HPA ändrar deploymentens önskade antal repliker och Kubernetes skapar eller tar bort poddar för att nå det antalet. Fler poddar ger inte automatiskt mer total kapacitet på en enda laptop.

## Variabler och outputs

| Variabel | Standardvärde | Betydelse |
| --- | --- | --- |
| `min_replicas` | `1` | Minsta antal poddar som HPA ska hålla. |
| `max_replicas` | `5` | Högsta antal poddar som HPA får skala till. |
| `external_port` | `8081` | Servicens ingångsport. Nginx lyssnar fortfarande på port 80 i podden. |

Skriptet kräver positiva heltal för repliker och att maximum inte är mindre än minimum. Portvalet är begränsat till 8080–9000. Ett tomt portsvar använder 8081. Dessa inmatningskontroller ligger i Bash; direkt körning av Terraform går inte genom dem.

Terraform visar tre outputs efter apply:

- `namespace`: appens namespace.
- `deployment_name`: deploymentens namn.
- `repicas`: antal repliker som Terraform läser från deploymenten. Namnet är stavat så i koden. Det är inte en löpande mätning av HPA.

Visa senast sparade outputs med:

```bash
terraform output
```

## Installation och körning

Klona repot:

```bash
git clone https://github.com/ettan5/EliasTerraform.git
cd EliasTerraform
```

Kontrollera anslutningen och Terraform-konfigurationen:

```bash
kubectl get nodes
terraform init
terraform validate
```

Kontrollera att sökvägen till kubeconfig i `main.tf` passar din miljö. Kör sedan:

```bash
bash deploy.sh
```

Skriptet frågar efter minimum, maximum och extern port. Exempelvis minimum 1, maximum 5 och port 8081.

Körningen sker i följande ordning:

1. Läser in funktionerna och kör `terraform init` om `.terraform` saknas.
2. Läser och kontrollerar min/max samt port. Felaktiga svar ger en ny fråga.
3. Skickar värdena till `Terraform_setup` som argument.
4. Kör `terraform plan`, sparar planen i `tfplan` och genomför den med `terraform apply tfplan`.
5. Listar appens poddar i namespacet `webb`.
6. Anropar `Test_nginx` med den valda porten.

En sparad plan genomförs utan en extra bekräftelsefråga. För att själv granska planen innan apply kan du i stället köra:

```bash
terraform plan -var="min_replicas=1" -var="max_replicas=5" -var="external_port=8081" -out=tfplan
```

Läs planen och genomför den sedan separat:

```bash
terraform apply tfplan
```

## Funktioner och felhantering

| Funktion | Vad den gör |
| --- | --- |
| `read_replicas` | Tar emot frågetext och en nedre gräns. Frågar igen tills svaret är giltigt och lämnar värdet i `REPLY`. |
| `Port` | Frågar efter port och sparar den i Bash-variabeln `external_port`. |
| `Terraform_setup` | Tar emot minimum, maximum och port. Kör plan och apply. |
| `Test_nginx` | Tar emot porten och letar efter texten `Welcome to nginx!` i HTTP-svaret. |

`Test_nginx` gör upp till tio försök med fem sekunders paus efter varje misslyckat försök. Vid lyckat test returnerar funktionen `0`. Om alla försök misslyckas skriver den ett felmeddelande och returnerar `1`. curl har ännu ingen timeout, så hela testet kan ta längre tid än pausernas sammanlagda tid.

`set -e` gör att skriptet avbryts vid exempelvis ett misslyckat Terraform-kommando eller ett misslyckat webbtest. Skriptet skriver för närvarande `Deployment completed successfully` direkt efter apply, före webbtestet. Det meddelandet visar därför att Terraform-steget lyckades, inte att HTTP-kontrollen redan har passerat. Slutmeddelandet med adressen kommer efter webbtestet.

## Verifiering och resultat

Visa resurserna:

```bash
kubectl get deployment,pods,svc,hpa -n webb
kubectl rollout status deployment/local-nginx -n webb --timeout=120s
kubectl top pods -n webb
```

Testa webbsidan på den valda porten. Om du valde 8081:

```bash
curl http://localhost:8081
```

Vid behov kan en separat terminal användas för port-forwarding, med en ledig lokal port:

```bash
kubectl port-forward -n webb svc/local-nginx-service 18081:8081
```

Då nås sidan på `http://localhost:18081`. Byt målporten 8081 i kommandot om Servicen använder en annan port.

Under arbetet har Terraform-valideringen och Bash-syntaxkontrollerna passerat. Inmatningsfunktionen har testats med noll, text, ett maximum under minimum och giltiga värden. Webbkontrollen har också hittat Nginx välkomsttext på en vald port.

I ett tidigare belastningstest skalade HPA från en till fyra redo poddar. Nedskalning verifierades inte i det testet. Det visar att uppskalningen fungerade då, men ersätter inte ett sluttest av den senaste versionen av hela skriptkedjan.

## Felsökning

- **Inga resurser hittas:** använd `-n webb`. Utan det kan kubectl leta i `default`.
- **Metrics API not available:** kontrollera Metrics Server och nodens IP-adress. När laptopen bytt nätverk har k3s tidigare behållit en gammal nodadress. En omstart av k3s uppdaterade adressen, och mätvärden började fungera efter en stund.
- **Webbtestet misslyckas:** kontrollera vald port, Servicens status, att poddarna är redo och att sidan innehåller den förväntade texten. En egen startsida behöver ett annat test än Nginx standardtext.
- **Ny port svarar inte direkt:** K3s ServiceLB kan behöva tid för att börja använda porten. Därför gör webbtestet flera försök.
- **Porten är upptagen:** välj en ledig port. Traefik kan redan använda port 80 och 443 i k3s.
- **Funktionsfilen hittas inte:** kör skriptet från projektmappen och kontrollera att `BashFunctions.sh` finns där.

## Reflektion och fortsatt utveckling

Projektet visar hur Terraform, Kubernetes och Bash kan användas tillsammans. Terraform beskriver resurserna, Kubernetes håller poddarna igång och Bash kopplar ihop inmatning, driftsättning och verifiering.

Under arbetet blev skillnaden mellan en körande pod och en fungerande webbsida tydlig. Terraform kan ha genomfört ändringen även om en ny port ännu inte svarar. Webbkontrollen behöver därför testa HTTP och göra omförsök. Labels och namespace har också olika roller: labels används för urval medan namespace samlar resurserna i ett område i klustret.

Förbättringar som återstår är att ange en bestämd Nginx-version, lägga till timeout för HTTP-anropen och låta Terraform ignorera ändringar i antalet repliker när HPA styr skalningen. Deploymenten anger fortfarande en replik, så en senare apply kan annars återställa HPA:s val. Arraybaserad verktygskontroll och särskild loggfilshantering är inte implementerade ännu.

State-filer och sparade planer behövs för Terraform-körningen och kan innehålla känsliga uppgifter. De ska inte läggas i GitHub-repot. `.terraform/` innehåller hämtade providers och ska också hållas utanför versionshanteringen. Däremot bör `.terraform.lock.hcl` följa med projektet.
