# ArgoCD Configuration

This directory contains the ArgoCD Application manifests that implement the **app-of-apps pattern** for deploying the entire demo environment.

## Overview

The app-of-apps pattern is a GitOps approach where a parent ArgoCD Application manages multiple child Applications. This creates a declarative, version-controlled deployment pipeline where:

1. The parent app (`app-of-apps.yaml`) defines which components to install
2. Each child app (in `applications/`) points to its specific manifests
3. ArgoCD continuously monitors Git and automatically syncs changes
4. All infrastructure is defined as code in Git

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Git Repository                        │
│                                                              │
│  argocd/                                                     │
│  ├── app-of-apps.yaml         (Parent Application)          │
│  └── applications/                                           │
│      ├── openshift-gitops.yaml                              │
│      ├── openshift-pipelines.yaml                           │
│      ├── openshift-devspaces.yaml                           │
│      ├── developer-hub.yaml                                 │
│      └── kitchensink.yaml                                   │
│                                                              │
│  components/                   (Actual resources)            │
│  ├── developer-hub/                                          │
│  ├── devspaces/                                              │
│  ├── pipelines/                                              │
│  └── kitchensink/                                            │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ ArgoCD monitors & syncs
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    OpenShift Cluster                         │
│                                                              │
│  ┌──────────────────┐                                       │
│  │  ArgoCD Server   │                                       │
│  └────────┬─────────┘                                       │
│           │                                                  │
│           │ Creates child Applications                      │
│           ▼                                                  │
│  ┌──────────────────────────────────────────────┐          │
│  │  Child Applications                           │          │
│  │  ├── OpenShift Pipelines                     │          │
│  │  ├── OpenShift DevSpaces                     │          │
│  │  ├── Developer Hub                           │          │
│  │  └── Kitchensink                             │          │
│  └──────────────────────────────────────────────┘          │
│                    │                                         │
│                    │ Deploys actual resources               │
│                    ▼                                         │
│  ┌──────────────────────────────────────────────┐          │
│  │  Kubernetes Resources                         │          │
│  │  (Operators, Deployments, Services, etc.)    │          │
│  └──────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

## File Structure

### app-of-apps.yaml

The parent Application that bootstraps everything. This is the **only** manifest you apply manually - all other applications are created automatically by ArgoCD.

**Key configuration:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rh-jboss-demo
  namespace: openshift-gitops
spec:
  source:
    repoURL: https://github.com/YOUR_USERNAME/rh-jboss-demo  # UPDATE THIS
    targetRevision: main
    path: argocd/applications  # Points to child app definitions
  destination:
    server: https://kubernetes.default.svc
    namespace: openshift-gitops
  syncPolicy:
    automated:
      prune: true       # Remove resources when deleted from Git
      selfHeal: true    # Automatically sync when drift detected
```

**What it does:**
- Creates an ArgoCD Application named `rh-jboss-demo`
- Monitors the `argocd/applications/` directory in your Git repo
- Automatically creates child Applications for each YAML file found
- Enables auto-sync and self-healing for fully automated GitOps

### applications/ Directory

Contains individual ArgoCD Application manifests for each component. These are the "child" applications managed by the app-of-apps.

#### openshift-gitops.yaml

**Purpose**: Ensures OpenShift GitOps operator is installed and configured.

**What it deploys**: 
- Operator subscription (if not already installed by bootstrap)
- ClusterRole bindings for ArgoCD to manage cluster-wide resources
- ArgoCD instance configuration

**Target Namespace**: `openshift-gitops`

**Sync Policy**: Automatic with self-healing

#### openshift-pipelines.yaml

**Purpose**: Installs Tekton/OpenShift Pipelines for CI/CD.

**What it deploys**:
- OpenShift Pipelines operator subscription
- TektonConfig custom resource for cluster configuration
- Pipeline service account with required permissions

**Target Namespace**: `openshift-pipelines` (operator runs cluster-wide)

**Sync Policy**: Automatic

**Key Features**:
- Tekton Pipelines (define build workflows)
- Tekton Triggers (webhook-based pipeline triggers)
- Tekton Dashboard (UI for viewing pipeline runs)

#### openshift-devspaces.yaml

**Purpose**: Installs OpenShift DevSpaces for browser-based development.

**What it deploys**:
- DevSpaces operator subscription
- CheCluster custom resource (DevSpaces instance)
- Workspace configurations and devfiles

**Target Namespace**: `openshift-devspaces`

**Sync Policy**: Automatic

**Configuration Highlights**:
- Browser-based VS Code experience
- Pre-configured JBoss development environment
- Hot-reload enabled for fast inner-loop iteration

#### developer-hub.yaml

**Purpose**: Deploys Red Hat Developer Hub (Backstage) for developer portal.

**What it deploys**:
- Developer Hub operator subscription
- Backstage instance configuration
- Software templates for JBoss applications
- Catalog configuration

**Target Namespace**: `rhdh`

**Sync Policy**: Automatic

**Features**:
- Self-service application scaffolding
- Software templates (JBoss quickstarts)
- Developer onboarding documentation
- API catalog and service registry

#### kitchensink.yaml

**Purpose**: Deploys the demo JBoss application with full CI/CD.

**What it deploys**:
- Namespace: `kitchensink-dev`
- Deployment and Service for the app
- Route for external access
- Tekton Pipeline for builds
- PipelineRun triggers
- Image registry credentials

**Target Namespace**: `kitchensink-dev`

**Sync Policy**: Automatic with image update automation

**Pipeline Flow**:
1. Git push triggers webhook
2. Tekton pipeline: clone → build → test → containerize
3. Push image to Quay.io with vulnerability scanning
4. Update deployment manifest in Git with new image tag
5. ArgoCD detects manifest change and deploys

## How It Works

### Initial Deployment

1. **Bootstrap script** (`bootstrap/install.sh`) installs GitOps operator
2. Script applies `app-of-apps.yaml` to cluster
3. ArgoCD server starts and detects the parent app
4. Parent app points to `argocd/applications/` directory
5. ArgoCD creates child Applications for each YAML file
6. Child apps sync their respective components from `components/` directory

### Continuous GitOps Loop

```
Developer → Git Push → ArgoCD detects change → Syncs to cluster → App updated
     ▲                                                                │
     └────────────────── Monitors for drift ◀──────────────────────┘
```

**Auto-Sync**: ArgoCD polls Git every 3 minutes (configurable)
**Self-Heal**: If someone manually changes a resource on cluster, ArgoCD reverts it to match Git
**Pruning**: If you delete a manifest from Git, ArgoCD removes it from the cluster

### Image Update Automation

For the kitchensink app, we use a hybrid approach:

1. **Tekton pipeline** builds new image and pushes to registry
2. Pipeline uses `kustomize` or `yq` to update image tag in `components/kitchensink/k8s/deployment.yaml`
3. Pipeline commits the change back to Git
4. ArgoCD detects the Git change and syncs the new image

This is **GitOps-native** - Git is always the source of truth, even for image tags.

## Configuration

### Updating Repository URL

**CRITICAL**: Before deploying, update the Git repository URL in all files:

```bash
# From repository root
export YOUR_REPO="https://github.com/YOUR_USERNAME/rh-jboss-demo"

# Update app-of-apps
sed -i "s|https://github.com/CHANGEME/rh-jboss-demo|${YOUR_REPO}|g" argocd/app-of-apps.yaml

# Update all child applications
find argocd/applications -name "*.yaml" -exec sed -i "s|https://github.com/CHANGEME/rh-jboss-demo|${YOUR_REPO}|g" {} \;

# Verify
grep -r "repoURL:" argocd/
```

### Customizing Sync Policy

Each application can have different sync policies. Edit the individual YAML files:

```yaml
spec:
  syncPolicy:
    automated:
      prune: true        # Set to false to prevent auto-deletion
      selfHeal: true     # Set to false to allow manual changes
    syncOptions:
      - CreateNamespace=true  # Auto-create target namespace
      - PruneLast=true        # Delete resources after new ones are healthy
```

**Options:**
- **Manual sync**: Remove `automated:` section entirely
- **Auto-sync without prune**: Set `prune: false`
- **Auto-sync without self-heal**: Set `selfHeal: false`

### Targeting Different Clusters

To deploy to multiple clusters (dev, staging, prod):

```yaml
spec:
  destination:
    server: https://api.prod-cluster.example.com  # Different cluster
    namespace: kitchensink-prod
```

Or use ArgoCD's `ApplicationSet` for multi-cluster deployments.

## Monitoring and Management

### View All Applications

```bash
# List all ArgoCD applications
oc get applications -n openshift-gitops

# Watch in real-time
watch oc get applications -n openshift-gitops
```

### Check Sync Status

```bash
# Detailed status of parent app
oc describe application rh-jboss-demo -n openshift-gitops

# Detailed status of child app
oc describe application kitchensink -n openshift-gitops
```

### Manual Sync

If auto-sync is disabled or you want to force a sync:

```bash
# Sync specific application
oc patch application kitchensink -n openshift-gitops \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'

# Or use ArgoCD CLI
argocd app sync kitchensink
```

### View Sync Logs

```bash
# ArgoCD server logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-server

# Application controller logs (handles sync operations)
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-application-controller
```

### ArgoCD UI

Access the web UI for visual management:

```bash
# Get ArgoCD URL
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'

# Get admin password
oc get secret openshift-gitops-cluster -n openshift-gitops \
  -o jsonpath='{.data.admin\.password}' | base64 -d
```

**UI Features:**
- Visual application topology
- Sync status and health indicators
- Manual sync buttons
- Resource tree view
- Real-time log streaming
- Diff view (Git vs cluster)

## Troubleshooting

### Application Stuck in "Progressing"

**Symptom**: Application shows "Progressing" status for extended period

**Diagnosis**:
```bash
# Check what resources are pending
oc describe application kitchensink -n openshift-gitops

# Look for health status of individual resources
oc get application kitchensink -n openshift-gitops -o yaml | grep -A 20 status
```

**Common Causes**:
- Deployment waiting for image pull
- Operator installation in progress
- Resource dependencies not met

**Solution**: Wait for underlying resources to become ready, or check resource-specific logs

### Application Shows "OutOfSync"

**Symptom**: Application status is "OutOfSync"

**Diagnosis**:
```bash
# View diff between Git and cluster
argocd app diff kitchensink

# Or check in UI
```

**Common Causes**:
- Manual changes made to cluster resources
- Sync policy doesn't allow auto-sync
- Git repository not accessible

**Solution**:
- If self-heal is enabled, ArgoCD will auto-correct
- Otherwise, manually sync: `argocd app sync kitchensink`

### Application Shows "Degraded" Health

**Symptom**: Application synced but health is "Degraded"

**Diagnosis**:
```bash
# Check which resources are unhealthy
oc get application kitchensink -n openshift-gitops -o jsonpath='{.status.resources[*]}' | jq

# Check the actual resource
oc get deployment kitchensink -n kitchensink-dev
oc describe deployment kitchensink -n kitchensink-dev
```

**Common Causes**:
- Deployment has 0 ready pods
- Operator failed to install
- CRD issues

**Solution**: Fix the underlying resource issue (usually deployment or pod problems)

### Repository Authentication Issues

**Symptom**: "Failed to load target state: authentication required"

**Diagnosis**:
```bash
# Check ArgoCD repository credentials
oc get secret -n openshift-gitops -l argocd.argoproj.io/secret-type=repository
```

**Solution**:
```bash
# For private repos, add credentials
oc create secret generic git-repo-creds \
  -n openshift-gitops \
  --from-literal=username=YOUR_USERNAME \
  --from-literal=password=YOUR_TOKEN

oc label secret git-repo-creds \
  -n openshift-gitops \
  argocd.argoproj.io/secret-type=repository
```

### Child Applications Not Created

**Symptom**: Parent app is healthy but child apps don't appear

**Diagnosis**:
```bash
# Check if parent app is pointing to correct path
oc get application rh-jboss-demo -n openshift-gitops -o yaml | grep path

# Check ArgoCD application-controller logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-application-controller --tail=100
```

**Common Causes**:
- Incorrect `path` in app-of-apps.yaml
- Repository URL wrong
- YAML syntax errors in child applications

**Solution**: Verify repository URL and path are correct, check YAML syntax

## Advanced Patterns

### Multi-Environment Deployments

Use overlays with Kustomize:

```
components/kitchensink/
├── base/                    # Common resources
│   ├── deployment.yaml
│   └── service.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml
    ├── staging/
    │   └── kustomization.yaml
    └── prod/
        └── kustomization.yaml
```

Create separate ArgoCD apps for each environment:

```yaml
# applications/kitchensink-dev.yaml
spec:
  source:
    path: components/kitchensink/overlays/dev

# applications/kitchensink-prod.yaml
spec:
  source:
    path: components/kitchensink/overlays/prod
```

### Progressive Delivery with Rollouts

Replace Deployments with Argo Rollouts for advanced deployment strategies:

```yaml
# Blue-green deployment
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    blueGreen:
      activeService: kitchensink
      previewService: kitchensink-preview
```

### ApplicationSet for DRY Configuration

Use ApplicationSet to generate multiple similar applications:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: kitchensink-envs
spec:
  generators:
  - list:
      elements:
      - env: dev
      - env: staging
      - env: prod
  template:
    metadata:
      name: 'kitchensink-{{env}}'
    spec:
      source:
        path: 'components/kitchensink/overlays/{{env}}'
      destination:
        namespace: 'kitchensink-{{env}}'
```

## Best Practices

1. **Git as Single Source of Truth**: Never manually edit cluster resources. Always change Git first.

2. **Immutable Infrastructure**: Use image tags (not `latest`), commit SHAs, or semantic versions for reproducibility.

3. **Namespace Isolation**: Use separate namespaces for different applications and environments.

4. **Resource Limits**: Always set resource requests/limits to prevent resource contention.

5. **Health Checks**: Define proper liveness and readiness probes so ArgoCD can accurately report health.

6. **Prune Carefully**: Enable `prune: true` only when you're confident ArgoCD should auto-delete resources.

7. **Use Sync Waves**: For complex apps with dependencies, use sync waves to control deployment order:
   ```yaml
   metadata:
     annotations:
       argocd.argoproj.io/sync-wave: "1"  # Deploy before wave 2
   ```

8. **Monitor Sync Failures**: Set up alerts for ArgoCD sync failures to catch issues early.

## References

- [ArgoCD Official Documentation](https://argo-cd.readthedocs.io/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [OpenShift GitOps](https://docs.openshift.com/gitops/latest/)
- [Sync Options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)
- [Health Assessment](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/)
