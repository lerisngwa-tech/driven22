# Landmark Technology - DevOps End-to-End Application

A Node.js application deployed to AWS EKS with full CI/CD pipelines (Jenkins, GitHub Actions, CircleCI).

---

## Architecture

```
Developer → Git Push → CI/CD Pipeline → Docker Hub → EKS Cluster → LoadBalancer → Users
```

---

## Prerequisites

- AWS Account with IAM user (programmatic access)
- AWS CLI installed and configured
- Terraform installed (v1.3+)
- kubectl installed
- Docker installed
- Helm installed
- A Docker Hub account

---

## Step 1: Clone the Repository

```bash
git clone https://github.com/LandmakTechnology/devopsapp.git
cd devopsapp
```

---

## Step 2: Build, Login & Push Docker Image

Build the image using your own Docker Hub account:

```bash
# Replace with your Docker Hub account and repo name
export DOCKER_REPO="your-dockerhub-username/devopsapp"
export IMAGE_TAG="v1"

# Build
docker build -t ${DOCKER_REPO}:${IMAGE_TAG} .
docker tag ${DOCKER_REPO}:${IMAGE_TAG} ${DOCKER_REPO}:latest

# Login
docker login -u your-dockerhub-username

# Push
docker push ${DOCKER_REPO}:${IMAGE_TAG}
docker push ${DOCKER_REPO}:latest
```

---

## Step 3: Deploy Infrastructure (Terraform)

Provision the VPC and EKS cluster with 2 x t3.medium nodes:

```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```

This creates:
- VPC with 2 public subnets (tagged for ELB)
- Internet Gateway + Route Table
- EKS Cluster with IAM roles
- Node Group (2 x t3.medium)

---

## Step 4: Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name landmark-eks-cluster
kubectl get nodes
```

---

## Step 5: Tag Subnets for Load Balancer Discovery

The AWS Load Balancer Controller requires specific tags on subnets to discover them. If your LoadBalancer stays in `<pending>` state, tag your subnets:

```bash
# Get your subnet IDs
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<YOUR_VPC_ID>" --query 'Subnets[].SubnetId' --output text

# Tag each public subnet (replace subnet IDs with yours)
aws ec2 create-tags --resources subnet-xxxxx subnet-yyyyy --tags \
  Key=kubernetes.io/role/elb,Value=1 \
  Key=kubernetes.io/cluster/landmark-eks-cluster,Value=owned
```

**Required subnet tags:**
| Tag Key | Value | Purpose |
|---------|-------|--------|
| `kubernetes.io/role/elb` | `1` | Tells LB controller to use these subnets for internet-facing LBs |
| `kubernetes.io/cluster/landmark-eks-cluster` | `owned` | Associates subnets with the cluster |

> **Note:** For private subnets (internal LBs), use `kubernetes.io/role/internal-elb` = `1` instead.

---

## Step 6: Install AWS Load Balancer Controller

Required for the LoadBalancer service to provision an ELB:

```bash
# 1. Create OIDC provider
eksctl utils associate-iam-oidc-provider --cluster landmark-eks-cluster --region us-east-1 --approve

# 2. Create IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.1/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json

# 3. Create service account
eksctl create iamserviceaccount \
  --cluster=landmark-eks-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# 4. Install via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=landmark-eks-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1 \
  --set vpcId=<VPC_ID>
# 5. Verify
kubectl get deployment -n kube-system aws-load-balancer-controller
```

---

## Step 7: Deploy the Application Manually

Replace the image placeholder in the manifest with your actual image, then deploy:

```bash
# Replace the placeholder with your image
sed -i 's|chafah/devopsapp:latest|your-dockerhub-username/devopsapp:v1|g' kubernetes/03-deployment/deployment.yaml

# Deploy
kubectl apply -f kubernetes/01-namespace/namespace.yaml
kubectl apply -f kubernetes/04-configmap/configmap.yaml
kubectl apply -f kubernetes/03-deployment/deployment.yaml
kubectl apply -f kubernetes/03-deployment/service.yaml
```

---

## Step 8: Access the Application

```bash
# Get the LoadBalancer URL
kubectl get svc landmark-app-service -n landmark

# Or extract just the hostname
kubectl get svc landmark-app-service -n landmark -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Open the URL in your browser on port 80. It may take 2-3 minutes for the ELB to become active.

---

## CI/CD Pipeline Options

Choose one of the following CI/CD tools to automate the build and deploy process.

All pipelines use a `DOCKER_REPO` environment variable (e.g., `landmark/devopsapp`). Update this in the pipeline file to match your Docker Hub `account/repo`. The pipelines automatically replace the `chafah/devopsapp:latest` placeholder in the Kubernetes manifests at deploy time.

---

### Option A: Jenkins

**File:** `Jenkinsfile`

#### Jenkins Setup
1. Deploy a Jenkins server (use the `jenkins/` folder or a Docker container):
   ```bash
   docker run -d -p 8080:8080 jenkins/jenkins:latest
   ```
2. Access Jenkins at `http://<JENKINS_IP>:8080`
3. Get the initial password:
   ```bash
   docker exec <container_id> cat /var/jenkins_home/secrets/initialAdminPassword
   ```
4. Install suggested plugins

#### Credentials Required
| Credential ID | Type | Description |
|---------------|------|-------------|
| `DOCKER` | Username/Password | Docker Hub credentials |
| `AWS_ACCESS_KEY` | Secret text | AWS Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | Secret text | AWS Secret Access Key |

#### Create the Pipeline
1. New Item → Pipeline
2. Pipeline Definition → Pipeline script from SCM
3. SCM: Git
4. Repository URL: `https://github.com/LandmakTechnology/devopsapp.git`
5. Branch: `*/main`
6. Script Path: `Jenkinsfile`
7. Save and Build

#### Pipeline Stages
```
Git Checkout → Build Docker Image → Push to Docker Hub → Deploy to EKS
```

#### (Optional) GitHub Webhook for Auto-Trigger
1. In GitHub: Settings → Webhooks → Add webhook
   - Payload URL: `http://<JENKINS_IP>:8080/github-webhook/`
   - Content type: `application/json`
2. In Jenkins: Pipeline → Configure → Build Triggers → Select "GitHub hook trigger for GITScm polling"

---

### Option B: GitHub Actions

**File:** `.github/workflows/deploy.yml`

#### Secrets Required
Add these in GitHub → Settings → Secrets and variables → Actions:

| Secret | Description |
|--------|-------------|
| `DOCKER_USERNAME` | Docker Hub username |
| `DOCKER_PASSWORD` | Docker Hub password |
| `AWS_ACCESS_KEY_ID` | AWS Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Access Key |

#### How It Works
- Triggers automatically on push to `main` branch
- Can also be triggered manually via "Run workflow" button
- Two jobs: `build-and-push` → `deploy`

#### Pipeline Stages
```
Checkout → Build & Push Image → Configure AWS → Update kubeconfig → Deploy to EKS → Print LB URL
```

---

### Option C: CircleCI

**File:** `.circleci/config.yml`

#### Contexts Required
Create these in CircleCI → Organization Settings → Contexts:

**Context: `docker-credentials`**
| Variable | Description |
|----------|-------------|
| `DOCKER_USERNAME` | Docker Hub username |
| `DOCKER_PASSWORD` | Docker Hub password |

**Context: `aws-credentials`**
| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Access Key |
| `AWS_DEFAULT_REGION` | `us-east-1` |

#### Setup
1. Go to [circleci.com](https://circleci.com) and connect your GitHub repo
2. Create the contexts above
3. Push to `main` to trigger the pipeline

#### Pipeline Stages
```
Build & Push Image → Manual Approval → Deploy to EKS
```

The manual approval gate prevents accidental deployments to production.



---

## Cleanup

```bash
# Delete all Kubernetes resources
kubectl delete namespace landmark

# Destroy infrastructure
cd terraform
terraform destroy -auto-approve
```

---

## Happy Learning from Landmark Technology 🚀
# driven22
