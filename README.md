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
| `deploy.sh` | Läser in funktionsfilen, definierar en array med verktygsnamn och kör stegen i ordning. |
| `BashFunctions.sh` | Funktioner för verktygskontroll, minimum, maximum, portval, Terraform och webbkontroll. |
| `.terraform.lock.hcl` | Låser providerversionen och dess kontrollsummor. |
| `README.md` | Beskriver hur projektet fungerar och körs. |
| `logs/deploy.log` | Skapas vid lyckad körning och sparar resultatet från webbkontrollen. Ignoreras av Git. |

Alla kommandon nedan körs från projektmappen. Det behövs eftersom skriptet läser in `./BashFunctions.sh` och kör Terraform i den aktuella katalogen.

## Hur det fungerar

Terraform använder `hashicorp/kubernetes` med versionskravet `~> 3.0`. Kubernetes-resurserna för appen samlas i namespacet `webb`.

| Resurs | Namn | Uppgift |
| --- | --- | --- |
| Namespace | `webb` | Samlar appens resurser. |
| Deployment | `local-nginx` | Beskriver poddarnas innehåll. HPA styr önskat antal repliker. |
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

1. Läser in funktionerna och kontrollerar med `Programs_install` att kommandona Terraform och k3s finns. Funktionen installerar inga program och kontrollerar inte att klustret fungerar. Sedan körs `terraform init` om `.terraform` saknas.
2. Frågar först efter minimum med `read_min_replicas` och sedan maximum med `read_max_replicas`. Porten läses in med `Port`. Felaktiga svar ger en ny fråga.
3. Skickar värdena till `Terraform_setup` som argument.
4. Kör `terraform plan`, sparar planen i `tfplan` och genomför den med `terraform apply tfplan`.
5. Listar appens poddar i namespacet `webb`.
6. Anropar `Test_nginx` med den valda porten.
7. Skapar katalogen `logs` om den saknas och lägger till en resultatrad i `logs/deploy.log`. Skriver sedan att driftsättningen lyckades.

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
| `read_min_replicas` | Frågar efter ett positivt heltal och sparar svaret direkt i `min_replicas`. Frågar igen vid ogiltigt svar. |
| `read_max_replicas` | Tar emot minimum som argument. Kräver ett positivt heltal som är minst minimum och sparar svaret i `max_replicas`. |
| `Port` | Frågar efter port och sparar den i Bash-variabeln `external_port`. |
| `Terraform_setup` | Tar emot minimum, maximum och port. Kör plan och apply. Om apply misslyckas visas ett eget felmeddelande och funktionen returnerar `1`. |
| `Test_nginx` | Tar emot porten och letar efter texten `Welcome to nginx!` i HTTP-svaret. |
| `Programs_install` | Tar emot verktygsnamnen från arrayen i `deploy.sh`. En for-loop använder `command -v` för att hitta varje kommando i sökvägen. Skriver status med färg och returnerar `1` om något saknas. |

Arrayen `programs=("terraform" "k3s")` samlar namnen på verktygen som ska kontrolleras. Anropet `Programs_install "${programs[@]}"` skickar varje namn som ett eget argument. Inuti funktionen går `for program in "$@"` igenom argumenten ett i taget. Funktionen kör inte verktygen och installerar dem inte.

Inmatningen är uppdelad i två funktioner för att göra den lättare att följa. Frågetexten står direkt i respektive funktion. Först sparas minimum, sedan skickas det till maximumfunktionen som nedre gräns. Här behövs inte längre någon gemensam `prompt`-variabel eller `REPLY`.

`Test_nginx` gör upp till tio försök med fem sekunders paus efter varje misslyckat försök. Vid lyckat test returnerar funktionen `0`. Om alla försök misslyckas skriver den ett felmeddelande och returnerar `1`. curl har ännu ingen timeout, så hela testet kan ta längre tid än pausernas sammanlagda tid.

`set -e` gör att skriptet avbryts vid exempelvis ett misslyckat Terraform-kommando eller ett misslyckat webbtest. Vid ett apply-fel visar Terraform sin ursprungliga feltext. Därefter skriver funktionen `Error: Terraform apply failed.` och returnerar `1`, så att resten av deploy-skriptet inte körs. Det finns ingen automatisk återställning; resurser kan redan ha ändrats när felet uppstår.

Framgångsmeddelandet visas först efter ett lyckat webbtest och efter att resultatet har skrivits till filen. `mkdir -p logs` skapar katalogen om den saknas. `>> logs/deploy.log` lägger till en ny rad utan att skriva över tidigare resultat. Raden visar porten och det valda HPA-intervallet. Det är en enkel resultatlogg, inte en fullständig logg över fel eller alla kommandon.

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

Under arbetet har Terraform-valideringen och Bash-syntaxkontrollerna passerat. De uppdelade inmatningsfunktionerna har testats med noll, text, negativa tal, decimaler, ett maximum under minimum, giltiga värden och slut på indata. Webbkontrollen har också hittat Nginx välkomsttext på en vald port.

Vid sluttestet den 6 november 2026 passerade Terraform-valideringen med åtkomst till den lokala miljön. Hela `deploy.sh` kördes med minimum 1, maximum 7 och port 8080. Felaktiga svar avvisades, Terraform rapporterade inga nödvändiga ändringar och Nginx svarade. I ett separat test mot en port utan webbserver gjordes tio försök innan funktionen returnerade felstatus `1`. Kontroll av ett saknat verktyg och ett simulerat apply-fel gav också felstatus. Vid det simulerade apply-felet avbröts körningen före efterföljande steg.

Sluttestet använde ett befintligt kluster och befintliga resurser. En helt ny installation från tom miljö testades inte. Resultatfilen lades till efter denna körning och dess filskrivning kontrollerades separat.

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

Förbättringar som återstår är att ange en bestämd Nginx-version och lägga till timeout för HTTP-anropen. Deploymenten anger inte längre ett fast antal repliker i koden. Vid fortsatt utveckling behöver planer granskas så att Terraform och HPA inte motverkar varandras skalningsändringar. Resultatloggen kan senare utvecklas med tidsstämplar och felinformation.

State-filer och sparade planer behövs för Terraform-körningen och kan innehålla känsliga uppgifter. De ska inte läggas i GitHub-repot. `.terraform/` innehåller hämtade providers och ska också hållas utanför versionshanteringen. Däremot bör `.terraform.lock.hcl` följa med projektet.
