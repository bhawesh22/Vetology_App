# vetology-devops — DevOps Engineer Exercise v1.3

Complete solution for the **DevOps Engineer Interview Exercise v1.3**.

---

## Project Structure

```
vetology-devops/
├── Dockerfile                        # nginx:alpine image — envsubst injects WEBTEXT at runtime
├── index.html                        # HTML template with ${WEBTEXT} placeholder
├── Taskfile.yml                      # CI/CD tasks: build, lint, deploy, test, clean, cicd, deploywithdoppler
├── azure-pipelines-infra.yml         # Pipeline 1: Terraform + Ansible (infrastructure)
├── azure-pipelines-app.yml           # Pipeline 2: Lint + Build + Deploy + Test (app)
├── ansible/
│   ├── inventory.ini                 # VM inventory — fill in VM IP before running
│   └── playbook.yml                  # Installs Docker, Doppler CLI, Task on VM
└── terraform/
    ├── main.tf                       # Root: calls resource_group + compute modules
    ├── variables.tf                  # All root input variables (no defaults — all from tfvars)
    ├── outputs.tf                    # Root output: vm_public_ip (used by pipeline)
    ├── terraform.tfvars              # Actual values — git-ignored
    ├── terraform.tfvars.example      # Copy this → terraform.tfvars
    └── modules/
        ├── resource_group/
        │   ├── main.tf               # azurerm_resource_group
        │   ├── variables.tf
        │   └── outputs.tf            # Exposes name + location to root
        └── compute/
            ├── main.tf               # VNet, Subnet, PIP, NSG, NSG rules, NIC, VM — all in one
            ├── variables.tf
            └── outputs.tf            # Exposes vm_public_ip
```

---

## Application

`webtext-app` is an nginx-based web app that displays a single line of text from the `WEBTEXT` environment variable.

- Default text: **`Hello World!`**
- Override with `WEBTEXT` env var at `docker run` time

```bash
docker build -t webtext-app .
docker run -p 8081:80 -e WEBTEXT="That works" webtext-app
curl localhost:8081
# → That works
```

**How it works:**
- `index.html` contains `${WEBTEXT}` placeholder
- At container start, `envsubst` replaces `${WEBTEXT}` with the env var value
- nginx serves the resulting HTML on port 80

---

## Dockerfile

- Base image: `nginx:1.27-alpine` (small, secure)
- `ENV WEBTEXT="Hello World!"` — default if not passed
- `envsubst` replaces placeholder at container start
- `hadolint`-compatible (linted in `task lint`)

---

## Taskfile.yml

Requires [Task](https://taskfile.dev) (`go-task`).

```bash
# Install Task (Linux)
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin
```

### Available Tasks

| Command | Description |
|---|---|
| `task build` | Build `webtext-app` Docker image from `Dockerfile` + `index.html` |
| `task lint` | Run `hadolint` linter against `Dockerfile` |
| `task deploy` | Run container on port 8081 with `WEBTEXT="Development deploy"` |
| `task test` | `curl localhost:8081` and assert response contains `"Development deploy"` |
| `task clean` | Stop and remove the container |
| `task cicd` | Run lint → build → deploy → test (no clean) |
| `task deploywithdoppler` | Fetch `WEBTEXT` from Doppler and run container |

---

## Request 01 — Doppler Integration

1. Create a free account at [doppler.com](https://www.doppler.com)
2. Create project **`webtext-app`** → environment **`dev`**
3. Add secret: `WEBTEXT = Hello World from Doppler!`
4. Create a **Service Token** for the `dev` config
5. On the VM:

```bash
export DOPPLER_TOKEN="dp.st.dev.xxxxxxxxxxxx"
task deploywithdoppler
curl localhost:8081
# → Hello World from Doppler!
```

`deploywithdoppler` uses `doppler secrets get WEBTEXT --plain --token "$DOPPLER_TOKEN"` at runtime — no secrets stored on disk.

---

## Request 02 — Terraform (Azure VM)

### Module Layout

| Module | Resources |
|---|---|
| `modules/resource_group` | `azurerm_resource_group` |
| `modules/compute` | VNet, Subnet, Public IP, NSG + rules, NIC, NIC-NSG association, Linux VM |

All values come from `terraform.tfvars` — no hardcoded defaults in `variables.tf`.

### Run

```bash
cd terraform/

# 1. Copy and fill in values
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# 2. Init (downloads providers + configures Azure remote backend)
terraform init

# 3. Preview
terraform plan -out=tfplan

# 4. Apply
terraform apply tfplan
```

### Prerequisites

- Azure CLI logged in: `az login`
- Remote state storage account exists:
  ```bash
  az group create --name rg-vetology-tfstate --location eastus
  az storage account create --name stvetologytfstate \
    --resource-group rg-vetology-tfstate --sku Standard_LRS
  az storage container create --name tfstate \
    --account-name stvetologytfstate
  ```
- SSH key at `~/.ssh/id_rsa.pub` (or set `ssh_public_key_path` in `terraform.tfvars`)

### What gets provisioned

- Resource group `rg-vetology-devops`
- VNet + Subnet + Static Public IP
- NSG with rules: port 22 (SSH) + port 8081 (app)
- Ubuntu 22.04 LTS VM (`Standard_B2s`)

### Output

```bash
terraform output vm_public_ip   # VM ka public IP
```

---

## Request 03 — Ansible (Install Docker, Doppler CLI, Task)

```bash
# 1. Fill in VM IP
vim ansible/inventory.ini
# Replace <YOUR_VM_PUBLIC_IP> with actual IP

# 2. Run playbook
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

### What gets installed

| Tool | Version |
|---|---|
| Docker Engine (CE) | latest stable |
| Doppler CLI | latest (official apt repo) |
| Task (go-task) | v3.35.1 |

- `devops` user is added to the `docker` group
- Verification output printed at end of playbook

---

## Demo Flow

```bash
# Step 1 — Provision VM (Terraform)
cd terraform/
terraform init
terraform apply
cd ..

# Step 2 — Install tools on VM (Ansible)
vim ansible/inventory.ini          # fill in VM IP
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml

# Step 3 — Copy project files to VM
scp -r . devops@<VM_IP>:~/vetology-devops

# Step 4 — SSH into VM
ssh devops@<VM_IP>
cd ~/vetology-devops

# Step 5 — Run full CI/CD pipeline
task cicd
# lint ✓  build ✓  deploy ✓  test ✓

# Step 6 — Verify manually
curl localhost:8081
# → Development deploy

# Step 7 — Doppler deploy (Request 01)
export DOPPLER_TOKEN="dp.st.dev.xxxx"
task deploywithdoppler
curl localhost:8081
# → Hello World from Doppler!

# Step 8 — Cleanup
task clean
```

---

## Azure DevOps Pipelines

### Pipeline 1 — Infrastructure (`azure-pipelines-infra.yml`)

Triggered on changes to `terraform/**` or `ansible/**`.

| Stage | What it does |
|---|---|
| Terraform | Init → Plan → Apply → export `vm_public_ip` |
| Ansible | Install Docker + Doppler CLI + Task on VM |

**Required Variable Group:** `vetology-infra-secrets`
- `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`
- `SSH_PRIVATE_KEY` (base64 encoded)

### Pipeline 2 — App (`azure-pipelines-app.yml`)

Triggered on changes to `Dockerfile`, `index.html`, `Taskfile.yml`.

| Stage | What it does |
|---|---|
| Lint | `task lint` — hadolint on Dockerfile |
| Build | `task build` — image saved as pipeline artifact |
| DeployTest | Load image on VM → `task deploy` → `task test` |
| DeployDoppler | `task deploywithdoppler` on VM (main branch only) |

**Required Variable Group:** `vetology-app-secrets`
- `VM_IP`, `SSH_PRIVATE_KEY`, `DOPPLER_TOKEN`
