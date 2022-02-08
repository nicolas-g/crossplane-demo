# Crossplane POC

## Requirements
- A kubernetes cluster (can also be minikube, kind, k3d etc..)
- Access to GCP
- gcloud cli
- helm cli
- kubectl cli
- envsubst (optional)

## Installation

```
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
helm install crossplane --namespace crossplane-system crossplane-stable/crossplane --create-namespace --version 1.6.2
```

### Check Crossplane Status
```
helm list -n crossplane-system
kubectl get all -n crossplane-system
```

## Access

### GCP

For this demo, we will authenticate with our user account to GCP and use the temporary Application Default personal token.

:warning: This is not a proper way to configure crossplane in a Production environment (or even Development). Instead, you should use a Service Account Key or run crossplane from a Cluster where the crossplane Pod can use a Service Account with enough privilege to provision the resources you want.

Authenticate to GCP and setup your environment
```
gcloud auth login
gcloud config configurations create genesys-dev
gcloud config set project us-gcp-ame-con-bf9-npd-1
gcloud config set account usa-ngeorgakopoulos@deloitte.com
gcloud auth application-default login
```

Once you have run the `application-default login` command, a token will be created and saved under your home directory under the following path (MacOS):
```
/Users/{{ USER }}/.config/gcloud/legacy_credentials/{{ GCP_USER_EMAIL))/adc.json
```

You can then create a Kubernetes secret with your token by running
```
kubectl create secret generic gcp-creds -n crossplane-system --from-file=creds=/Users/{{ USER }}/.config/gcloud/legacy_credentials/{{ GCP_USER_EMAIL))/adc.json
```

### AWS
```
echo -e "[default]\naws_access_key_id = $AWS_ACCESS_KEY_ID\naws_secret_access_key = $AWS_SECRET_ACCESS_KEY" > creds.conf
```
```
kubectl create secret generic aws-creds -n crossplane-system --from-file=creds=./creds.conf
```


## GCP Deployment

### Crossplane GCP Provider

- https://crossplane.io/docs/v1.6/concepts/packages.html#provider-packages

Install the GCP provider
```
kubectl apply -f provider-gcp.yaml
```

provider-gcp.yaml:
```
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-gcp
spec:
  # https://doc.crds.dev/github.com/crossplane/provider-gcp
  package: crossplane/provider-gcp:v0.19.0
```

Check provider installation status
```
kubectl get providers.pkg.crossplane.io
\NAME           INSTALLED   HEALTHY   PACKAGE                           AGE
provider-gcp   True        True      crossplane/provider-gcp:v0.19.0   9m45s
```

### Crossplane GCP ProviderConfig

```
kubectl apply -f providerConfig.yaml
```

providerConfig.yaml:
```
---
apiVersion: gcp.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: gcp-demo-dev # <- CHANGEME
spec:
  projectID: xxx-yyy-zzz # <- CHANGEME
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: gcp-creds
      key: creds
```

confirm
```
kubectl get providerconfigs.gcp.crossplane.io
NAME              PROJECT-ID                 AGE
gcp-genesys-dev   us-gcp-ame-con-bf9-npd-1   31s
```

## Provision GCP resources with Crossplane


Create your `env-gcp-values.txt` file:
```
export PROVIDER_NAME=provider-gcp
export PROVIDER_VERSION="v0.19.0"

export PROVIDER_CONFIG_NAME=gcp-demo-dev
export PROVIDER_PROJECT_ID=xxx-yyy-zzz

export NETWORK_NAME=demo-network
export NETWORK_SUBNET_NAME=demo-subnet

export BUCKET_NAME=demo-bucket-xyz123

export KUBERENTES_CLUSTER_NAME=demo-cluster
export KUBERENTES_WORKER_NODE_NAME=demo-nodepool
export KUBERENTES_CLUSTER_NETWORK=$NETWORK_NAME
export KUBERENTES_CLUSTER_SUBNET=$NETWORK_SUBNET_NAME
```

Source your variables and check if the rendered result looks good:
```
source < env-gcp-values.txt
envsubst < env-subst-config-test > test-rendered.txt
```

Create the rendered templates manifrest by running `envsubst` command
```
source < env-gcp-values.txt
envsubst < templates/gcp/providerConfig.yaml > infra/gcp/providerConfig.yaml
envsubst < templates/gcp/bucket.yaml > infra/gcp/bucket.yaml
envsubst < templates/gcp/gke.yaml > infra/gcp/gke.yaml
envsubst < templates/gcp/network.yaml > infra/gcp/network.yaml
```

or run the `./render-templates.sh` script that will do all steps in one command.


```
kubectl apply -f infra/gcp
```

## Troubleshooting

```
kubectl get manage
kubectl get manage get cluster
kubectl get manage get nodepool
kubectl -n crossplane-system logs -l  app=crossplane
kubectl -n crossplane-system logs -l pkg.crossplane.io/provider=provider-gcp
kubectl -n crossplane-system logs -l app=crossplane-rbac-manager
```

## GCP Service Account Key

```
# replace this with your own gcp project id and the name of the service account
# that will be created.
PROJECT_ID=my-project
NEW_SA_NAME=test-service-account-name

# create service account
SA="${NEW_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud iam service-accounts create $NEW_SA_NAME --project $PROJECT_ID

# enable cloud API
SERVICE="sqladmin.googleapis.com"
gcloud services enable $SERVICE --project $PROJECT_ID

# grant access to cloud API
ROLE="roles/cloudsql.admin"
gcloud projects add-iam-policy-binding --role="$ROLE" $PROJECT_ID --member "serviceAccount:$SA"

# create service account keyfile
gcloud iam service-accounts keys create creds.json --project $PROJECT_ID --iam-account $SA
```
