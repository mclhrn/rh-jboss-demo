# Bootstrap Installation

This directory contains the installation script that bootstraps the entire Red Hat JBoss demo environment.

## Overview

The `install.sh` script automates the complete installation process using the **app-of-apps pattern** with ArgoCD. This approach:

1. Installs the OpenShift GitOps operator (ArgoCD)
2. Waits for ArgoCD to become ready
3. Deploys the app-of-apps ArgoCD application
4. ArgoCD then automatically installs all remaining components

## What Gets Installed

### Phase 1: GitOps Foundation (install.sh)
- **OpenShift GitOps Operator**: Installs ArgoCD on the cluster
- **App-of-Apps Application**: Parent ArgoCD app that manages all child apps

### Phase 2: Automated via ArgoCD (app-of-apps)
The app-of-apps automatically installs:

- **OpenShift Pipelines Operator**: Tekton CI/CD
- **OpenShift DevSpaces Operator**: Browser-based IDE
- **Red Hat Developer Hub**: Developer portal and software templates
- **Kitchensink Application**: Demo JBoss app with pipeline and manifests

## Prerequisites

Before running the installation:

1. **OpenShift Cluster Access**:
   - OpenShift 4.12 or later
   - Cluster admin privileges
   - At least 16GB RAM and 4 CPUs available across cluster

2. **CLI Tools Installed**:
   ```bash
   # Check oc is installed
   oc version
   
   # Verify you're logged in as cluster admin
   oc whoami
   oc auth can-i create namespace --all-namespaces
   ```

3. **Git Repository**:
   - Fork this repository to your Git provider
   - Update the repo URL in `../argocd/app-of-apps.yaml`
   - Ensure the repository is publicly accessible (or configure ArgoCD credentials)

## Installation

### Step 1: Update Repository URL

**CRITICAL**: Before installing, update the Git repository URL in the app-of-apps configuration:

```bash
# From the repository root
cd ..
export YOUR_REPO="https://github.com/YOUR_USERNAME/rh-jboss-demo"

# Update app-of-apps.yaml
sed -i "s|https://github.com/CHANGEME/rh-jboss-demo|${YOUR_REPO}|g" argocd/app-of-apps.yaml

# Verify the change
grep repoURL argocd/app-of-apps.yaml
```

### Step 2: Run the Installer

```bash
cd bootstrap
./install.sh
```

The script will:
1. Validate cluster connectivity
2. Create the `openshift-gitops` namespace
3. Install the OpenShift GitOps operator
4. Wait for ArgoCD to be ready (up to 5 minutes)
5. Apply the app-of-apps application
6. Display access URLs and next steps

### Step 3: Monitor Installation Progress

The app-of-apps will trigger installation of all components. Monitor progress:

```bash
# Watch ArgoCD applications
watch oc get applications -n openshift-gitops

# Or use the status command
./install.sh --status
```

Expected timeline:
- **Operators**: 2-3 minutes each (GitOps, Pipelines, DevSpaces, Developer Hub)
- **Application deployments**: 3-5 minutes
- **Total installation time**: 8-15 minutes

### Step 4: Access URLs

Once installation completes:

```bash
./install.sh --urls
```

This displays:
- ArgoCD UI URL and admin credentials
- Developer Hub URL
- DevSpaces dashboard URL
- Kitchensink application URL

## Installation Script Details

### Script Functions

The `install.sh` script provides several commands:

```bash
# Full installation (default)
./install.sh

# Check installation status
./install.sh --status

# Display access URLs
./install.sh --urls

# Uninstall all components
./install.sh --uninstall

# Help text
./install.sh --help
```

### What the Script Does

#### 1. Pre-flight Checks
```bash
# Validates:
- oc CLI is available
- Cluster connectivity
- Cluster admin permissions
- Git repository URL is updated
```

#### 2. Operator Installation
```bash
# Creates namespace
oc create namespace openshift-gitops

# Subscribes to OpenShift GitOps operator
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-operators
spec:
  channel: latest
  name: openshift-gitops-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# Waits for operator to be ready
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=openshift-gitops-server \
  -n openshift-gitops --timeout=300s
```

#### 3. App-of-Apps Deployment
```bash
# Applies the parent ArgoCD application
oc apply -f ../argocd/app-of-apps.yaml

# This triggers automatic installation of all child applications
```

#### 4. URL Extraction
```bash
# Retrieves routes for all deployed services
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'
oc get route backstage -n rhdh -o jsonpath='{.spec.host}'
oc get route devspaces -n openshift-devspaces -o jsonpath='{.spec.host}'
oc get route kitchensink -n kitchensink-dev -o jsonpath='{.spec.host}'
```

## Validation

After installation completes, verify all components are healthy:

### 1. Check Operators

```bash
# All operators should show "Succeeded" phase
oc get csv -A | grep -E "gitops|pipelines|devspaces|backstage"
```

Expected output:
```
openshift-gitops            gitops-operator.v1.x.x           OpenShift GitOps          1.x.x    Succeeded
openshift-operators         openshift-pipelines-operator-rh.vx.x.x   Red Hat OpenShift Pipelines   x.x.x    Succeeded
openshift-devspaces         devspaces.v3.x.x                OpenShift DevSpaces       3.x.x    Succeeded
rhdh                        backstage-operator.v1.x.x       Red Hat Developer Hub     1.x.x    Succeeded
```

### 2. Check ArgoCD Applications

```bash
oc get applications -n openshift-gitops
```

Expected output (all should show "Synced" and "Healthy"):
```
NAME                    SYNC STATUS   HEALTH STATUS
openshift-devspaces     Synced        Healthy
openshift-gitops        Synced        Healthy
openshift-pipelines     Synced        Healthy
developer-hub           Synced        Healthy
kitchensink             Synced        Healthy
```

### 3. Check Application Pods

```bash
# Developer Hub
oc get pods -n rhdh

# DevSpaces
oc get pods -n openshift-devspaces

# Kitchensink app
oc get pods -n kitchensink-dev

# Tekton
oc get pods -n openshift-pipelines
```

All pods should be in `Running` or `Completed` state.

### 4. Access the UIs

```bash
# Get all URLs
./install.sh --urls

# Test ArgoCD login
echo "ArgoCD Password: $(oc get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d)"
```

## Troubleshooting

### Issue: "Repository URL not updated"

**Problem**: The script detects `CHANGEME` in the repository URL

**Solution**:
```bash
cd ..
vi argocd/app-of-apps.yaml
# Update all repoURL fields to your forked repository
```

### Issue: GitOps operator not installing

**Problem**: Operator subscription fails or times out

**Solution**:
```bash
# Check operator status
oc get subscription openshift-gitops-operator -n openshift-operators

# View operator logs
oc logs -n openshift-operators -l name=openshift-gitops-operator

# Common fix: Delete and recreate subscription
oc delete subscription openshift-gitops-operator -n openshift-operators
./install.sh
```

### Issue: App-of-apps application not syncing

**Problem**: ArgoCD shows "OutOfSync" status

**Solution**:
```bash
# Check application details
oc describe application rh-jboss-demo -n openshift-gitops

# Manual sync
oc patch application rh-jboss-demo -n openshift-gitops \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{}}}}'

# Or use ArgoCD UI to sync manually
```

### Issue: Child applications not appearing

**Problem**: Only app-of-apps shows up, child apps not created

**Solution**:
```bash
# Verify app-of-apps is pointing to correct Git repo
oc get application rh-jboss-demo -n openshift-gitops -o yaml | grep repoURL

# Check ArgoCD server logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-server

# Ensure repository is accessible
curl -I https://github.com/YOUR_USERNAME/rh-jboss-demo
```

### Issue: DevSpaces or Developer Hub operator failing

**Problem**: Operator shows "Failed" status

**Solution**:
```bash
# Check operator events
oc get events -n openshift-devspaces --sort-by='.lastTimestamp'

# Verify cluster resources
oc adm top nodes

# May need to increase cluster capacity or adjust resource limits
```

### Issue: Kitchensink application not deploying

**Problem**: Pipeline fails or deployment doesn't start

**Solution**:
```bash
# Check pipeline runs
oc get pipelinerun -n kitchensink-dev

# View pipeline logs
tkn pipelinerun logs -f -n kitchensink-dev

# Check deployment status
oc get deployment kitchensink -n kitchensink-dev
oc describe deployment kitchensink -n kitchensink-dev
```

## Uninstallation

To completely remove the demo environment:

```bash
./install.sh --uninstall
```

This will:
1. Delete the app-of-apps (cascades to all child applications)
2. Prompt to remove operators
3. Delete all created namespaces
4. Remove ArgoCD CRDs (optional)

**Note**: Operators are shared resources. If you have other applications using these operators, decline the operator removal prompt.

### Manual Cleanup

If automatic uninstall fails:

```bash
# Delete all ArgoCD applications
oc delete application --all -n openshift-gitops

# Delete namespaces
oc delete namespace kitchensink-dev
oc delete namespace rhdh
oc delete namespace openshift-devspaces
oc delete namespace openshift-gitops

# Remove operators (if no other dependencies)
oc delete subscription openshift-gitops-operator -n openshift-operators
oc delete subscription openshift-pipelines-operator-rh -n openshift-operators
oc delete subscription devspaces -n openshift-operators
oc delete subscription backstage-operator -n openshift-operators

# Clean up CRDs (careful - this affects entire cluster)
# oc delete crd applications.argoproj.io
# oc delete crd pipelines.tekton.dev
# etc.
```

## Advanced Configuration

### Custom Namespace Names

Edit `../argocd/applications/*.yaml` before installation to change target namespaces:

```yaml
spec:
  destination:
    namespace: my-custom-namespace  # Change this
```

### Using Private Git Repository

If your fork is private, configure ArgoCD credentials:

```bash
# Create repository secret
oc create secret generic git-repo-creds \
  -n openshift-gitops \
  --from-literal=username=YOUR_USERNAME \
  --from-literal=password=YOUR_TOKEN

oc label secret git-repo-creds \
  -n openshift-gitops \
  argocd.argoproj.io/secret-type=repository
```

### Air-Gapped Installation

For disconnected clusters:

1. Mirror operators to internal catalog
2. Mirror container images to internal registry
3. Update image references in manifests
4. See Red Hat's disconnected installation documentation

## Next Steps

After successful installation:

1. **Review the demo script**: See `../docs/DEMO-SCRIPT.md`
2. **Try inner-loop development**: See `../docs/INNER-LOOP.md`
3. **Explore Developer Hub**: Access the URL from `./install.sh --urls`
4. **Test the pipeline**: Make a code change and push to Git

## Additional Resources

- [OpenShift GitOps Documentation](https://docs.openshift.com/gitops/latest/understanding_openshift_gitops/about-redhat-openshift-gitops.html)
- [ArgoCD App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [OpenShift Operator Installation](https://docs.openshift.com/container-platform/latest/operators/admin/olm-adding-operators-to-cluster.html)
