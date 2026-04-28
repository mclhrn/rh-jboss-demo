# OpenShift Pipelines (Tekton) Component

This component deploys OpenShift Pipelines (Tekton) for cloud-native CI/CD, providing automated build, test, and deployment workflows for the kitchensink JBoss application.

## Overview

OpenShift Pipelines solves the **manual deployment problem** by providing:

- **Automated builds**: Git push triggers automatic build pipeline
- **Containerized builds**: Build once, run anywhere (no "works on my machine")
- **Image scanning**: Quay.io integration for vulnerability detection
- **GitOps integration**: Pipeline updates Git manifests, ArgoCD deploys
- **Kubernetes-native**: Pipelines run as pods, scale automatically

## What Gets Deployed

### 1. Pipelines Operator

```yaml
components/pipelines/operator/subscription.yaml
```

**Purpose**: Installs OpenShift Pipelines (Tekton) cluster-wide

**Resources**:
- Subscription to `openshift-pipelines-operator-rh` from Red Hat catalog
- Installs into `openshift-operators` namespace
- Provides Tekton CRDs: Pipeline, PipelineRun, Task, TaskRun

**Installation Time**: 2-3 minutes

### 2. Kitchensink Pipeline

```yaml
components/pipelines/kitchensink-pipeline.yaml
```

**Purpose**: Defines the CI/CD workflow for the kitchensink app

**Pipeline Steps**:
1. **git-clone**: Clone source code from Git repository
2. **maven-build**: Build application with Maven (`mvn package`)
3. **build-image**: Build container image with Buildah
4. **push-image**: Push image to Quay.io registry
5. **scan-image**: Trigger Quay vulnerability scan
6. **update-manifest**: Update deployment YAML with new image tag
7. **git-commit**: Commit manifest change back to Git (triggers ArgoCD)

**Execution Time**: 5-8 minutes (first run ~10 min due to Maven cache)

### 3. Pipeline Trigger

```yaml
components/pipelines/trigger-binding.yaml
components/pipelines/trigger-template.yaml
components/pipelines/event-listener.yaml
```

**Purpose**: Automatically start pipeline on Git push events

**How it works**:
- GitHub/GitLab webhook sends push event to EventListener
- TriggerBinding extracts commit info (SHA, branch, author)
- TriggerTemplate creates PipelineRun with extracted parameters
- Pipeline executes automatically

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Git Repository                          │
│  (Developer pushes code change)                             │
└─────────────────────────────────────────────────────────────┘
                       │
                       │ Webhook (POST)
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                OpenShift Pipelines (Tekton)                  │
│                                                              │
│  ┌─────────────────┐                                        │
│  │ EventListener   │                                        │
│  │ (receives hook) │                                        │
│  └────────┬────────┘                                        │
│           │                                                  │
│           │ Creates PipelineRun                             │
│           ▼                                                  │
│  ┌─────────────────────────────────────────────────┐       │
│  │              Pipeline Execution                  │       │
│  │                                                  │       │
│  │  Step 1: git-clone                              │       │
│  │    └─▶ Clone source code                        │       │
│  │                                                  │       │
│  │  Step 2: maven-build                            │       │
│  │    └─▶ mvn clean package                        │       │
│  │                                                  │       │
│  │  Step 3: build-image                            │       │
│  │    └─▶ buildah bud -f Containerfile             │       │
│  │                                                  │       │
│  │  Step 4: push-image                             │       │
│  │    └─▶ buildah push quay.io/org/kitchensink:tag │       │
│  │           │                                      │       │
│  └───────────┼──────────────────────────────────────┘       │
│              │                                               │
└──────────────┼───────────────────────────────────────────────┘
               │
               │ Push container image
               ▼
┌─────────────────────────────────────────────────────────────┐
│                    Quay.io Registry                          │
│  ├─ Stores container image                                  │
│  ├─ Scans for vulnerabilities (Clair)                       │
│  └─ Provides image pull endpoint                            │
└─────────────────────────────────────────────────────────────┘
               │
               │ Update manifest with new image tag
               ▼
┌─────────────────────────────────────────────────────────────┐
│                   Git Repository                             │
│  components/kitchensink/k8s/deployment.yaml                 │
│  (Image tag updated by pipeline)                            │
└─────────────────────────────────────────────────────────────┘
               │
               │ ArgoCD detects change
               ▼
┌─────────────────────────────────────────────────────────────┐
│                      ArgoCD                                  │
│  └─▶ Syncs new image to cluster                             │
└─────────────────────────────────────────────────────────────┘
               │
               │ Deploy
               ▼
┌─────────────────────────────────────────────────────────────┐
│           Kitchensink Running (Updated)                      │
└─────────────────────────────────────────────────────────────┘
```

## Pipeline Definition

### Complete Pipeline YAML

```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: kitchensink-pipeline
  namespace: kitchensink-dev
spec:
  params:
    - name: git-url
      type: string
      description: Git repository URL
    - name: git-revision
      type: string
      description: Git revision (branch/tag/commit)
      default: main
    - name: image-name
      type: string
      description: Container image name
      default: quay.io/YOUR_ORG/kitchensink
    - name: path-context
      type: string
      description: Path to build context
      default: components/kitchensink

  workspaces:
    - name: shared-workspace
      description: Workspace for source code and artifacts
    - name: maven-settings
      description: Maven settings and local repository

  tasks:
    - name: git-clone
      taskRef:
        name: git-clone
        kind: ClusterTask
      params:
        - name: url
          value: $(params.git-url)
        - name: revision
          value: $(params.git-revision)
      workspaces:
        - name: output
          workspace: shared-workspace

    - name: maven-build
      taskRef:
        name: maven
        kind: ClusterTask
      runAfter:
        - git-clone
      params:
        - name: GOALS
          value:
            - clean
            - package
            - -DskipTests
        - name: CONTEXT_DIR
          value: $(params.path-context)
      workspaces:
        - name: source
          workspace: shared-workspace
        - name: maven-settings
          workspace: maven-settings

    - name: build-image
      taskRef:
        name: buildah
        kind: ClusterTask
      runAfter:
        - maven-build
      params:
        - name: IMAGE
          value: $(params.image-name):$(params.git-revision)
        - name: DOCKERFILE
          value: ./Containerfile
        - name: CONTEXT
          value: $(params.path-context)
      workspaces:
        - name: source
          workspace: shared-workspace

    - name: push-image
      taskRef:
        name: buildah
        kind: ClusterTask
      runAfter:
        - build-image
      params:
        - name: IMAGE
          value: $(params.image-name):$(params.git-revision)
      workspaces:
        - name: source
          workspace: shared-workspace

    - name: update-manifest
      taskRef:
        name: yq
        kind: Task
      runAfter:
        - push-image
      params:
        - name: file
          value: components/kitchensink/k8s/deployment.yaml
        - name: expression
          value: .spec.template.spec.containers[0].image = "$(params.image-name):$(params.git-revision)"
      workspaces:
        - name: source
          workspace: shared-workspace
```

## Step-by-Step Breakdown

### Step 1: git-clone

**Purpose**: Fetch source code from Git repository

**Task**: Uses the ClusterTask `git-clone` (provided by OpenShift Pipelines)

**Parameters**:
- `url`: Git repository URL (e.g., `https://github.com/user/rh-jboss-demo`)
- `revision`: Branch, tag, or commit SHA (e.g., `main`)

**What it does**:
```bash
git clone <url>
git checkout <revision>
```

**Output**: Source code in shared workspace

**Time**: 10-20 seconds

### Step 2: maven-build

**Purpose**: Compile Java code and package as WAR file

**Task**: Uses ClusterTask `maven`

**Parameters**:
- `GOALS`: Maven goals to execute (`clean`, `package`, `-DskipTests`)
- `CONTEXT_DIR`: Directory containing `pom.xml`

**What it does**:
```bash
cd components/kitchensink
mvn clean package -DskipTests
# Produces: target/kitchensink.war
```

**Output**: WAR file in `target/` directory

**Time**: 
- First run: 5-7 minutes (downloads all dependencies)
- Subsequent runs: 30-60 seconds (Maven cache persisted in workspace)

**Resource Requirements**:
- Memory: 2Gi (Maven compilation is memory-intensive)
- CPU: 1 core

### Step 3: build-image

**Purpose**: Build container image from source code

**Task**: Uses ClusterTask `buildah`

**Parameters**:
- `IMAGE`: Full image name with tag (e.g., `quay.io/myorg/kitchensink:abc123`)
- `DOCKERFILE`: Path to Containerfile/Dockerfile
- `CONTEXT`: Build context directory

**What it does**:
```bash
buildah bud \
  --file ./Containerfile \
  --tag quay.io/myorg/kitchensink:abc123 \
  components/kitchensink
```

**Containerfile** (simplified):
```dockerfile
FROM registry.redhat.io/jboss-eap-7/eap74-openjdk11-openshift-rhel8:latest
COPY target/kitchensink.war /deployments/
```

**Output**: Container image stored locally in build pod

**Time**: 1-2 minutes

**Security Note**: Runs with `buildah` SCC (Security Context Constraint) to allow rootless builds

### Step 4: push-image

**Purpose**: Push container image to Quay.io registry

**Task**: Uses ClusterTask `buildah` (push variant)

**Parameters**:
- `IMAGE`: Same image name from build step
- `TLSVERIFY`: `true` (enforce HTTPS)

**What it does**:
```bash
buildah push \
  --tls-verify=true \
  quay.io/myorg/kitchensink:abc123 \
  docker://quay.io/myorg/kitchensink:abc123
```

**Authentication**: Uses Kubernetes secret for registry credentials
```bash
oc create secret docker-registry quay-credentials \
  --docker-server=quay.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_TOKEN \
  -n kitchensink-dev

oc secrets link pipeline quay-credentials -n kitchensink-dev
```

**Output**: Image available at `quay.io/myorg/kitchensink:abc123`

**Time**: 30-60 seconds (depends on image size and network)

**Quay.io Scanning**: 
- Quay automatically scans pushed images with Clair
- Vulnerability report available in Quay UI
- Can configure pipeline to fail if critical CVEs found

### Step 5: update-manifest

**Purpose**: Update Kubernetes deployment manifest with new image tag

**Task**: Custom task using `yq` (YAML processor)

**Parameters**:
- `file`: Path to deployment YAML
- `expression`: yq expression to update image field

**What it does**:
```bash
yq eval '.spec.template.spec.containers[0].image = "quay.io/myorg/kitchensink:abc123"' \
  -i components/kitchensink/k8s/deployment.yaml

git add components/kitchensink/k8s/deployment.yaml
git commit -m "Update image to abc123"
git push
```

**Why this matters**: 
- Git is the source of truth (GitOps principle)
- ArgoCD only deploys what's in Git
- Pipeline doesn't deploy directly (ArgoCD does)

**Output**: Updated manifest in Git

**Time**: 5-10 seconds

**ArgoCD Sync**:
- ArgoCD polls Git every 3 minutes (default)
- Detects manifest change
- Syncs new image to cluster
- App updated in ~3-5 minutes after push

## Triggering the Pipeline

### Option 1: Manual Trigger (For Testing)

```bash
# Create a PipelineRun
oc create -f - <<EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: kitchensink-run-
  namespace: kitchensink-dev
spec:
  pipelineRef:
    name: kitchensink-pipeline
  params:
    - name: git-url
      value: https://github.com/YOUR_USERNAME/rh-jboss-demo
    - name: git-revision
      value: main
    - name: image-name
      value: quay.io/YOUR_ORG/kitchensink
  workspaces:
    - name: shared-workspace
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 5Gi
    - name: maven-settings
      emptyDir: {}
EOF

# Watch pipeline execution
tkn pipelinerun logs -f -n kitchensink-dev $(tkn pipelinerun list -n kitchensink-dev -o name | head -1)
```

### Option 2: Git Webhook (Automated)

**Setup EventListener**:

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: kitchensink-listener
  namespace: kitchensink-dev
spec:
  serviceAccountName: pipeline
  triggers:
    - name: github-push
      interceptors:
        - ref:
            name: github
          params:
            - name: eventTypes
              value: ["push"]
      bindings:
        - ref: kitchensink-trigger-binding
      template:
        ref: kitchensink-trigger-template
```

**TriggerBinding** (extracts data from webhook payload):

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: kitchensink-trigger-binding
  namespace: kitchensink-dev
spec:
  params:
    - name: git-url
      value: $(body.repository.clone_url)
    - name: git-revision
      value: $(body.after)  # Commit SHA
```

**TriggerTemplate** (creates PipelineRun):

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: kitchensink-trigger-template
  namespace: kitchensink-dev
spec:
  params:
    - name: git-url
    - name: git-revision
  resourcetemplates:
    - apiVersion: tekton.dev/v1beta1
      kind: PipelineRun
      metadata:
        generateName: kitchensink-run-
      spec:
        pipelineRef:
          name: kitchensink-pipeline
        params:
          - name: git-url
            value: $(tt.params.git-url)
          - name: git-revision
            value: $(tt.params.git-revision)
        workspaces:
          - name: shared-workspace
            volumeClaimTemplate:
              spec:
                accessModes: [ReadWriteOnce]
                resources:
                  requests:
                    storage: 5Gi
          - name: maven-settings
            emptyDir: {}
```

**Configure GitHub Webhook**:

```bash
# Get EventListener URL
EL_URL=$(oc get route el-kitchensink-listener -n kitchensink-dev -o jsonpath='{.spec.host}')

echo "Configure GitHub webhook:"
echo "  URL: https://${EL_URL}"
echo "  Content type: application/json"
echo "  Events: Just the push event"
echo "  Secret: (optional)"
```

Then in GitHub:
1. Go to your repo → Settings → Webhooks → Add webhook
2. Paste the EventListener URL
3. Select "application/json"
4. Choose "Just the push event"
5. Save

**Test**:
```bash
git commit -m "Test pipeline trigger" --allow-empty
git push

# Watch pipeline start automatically
tkn pipelinerun logs -f -n kitchensink-dev --last
```

## Monitoring Pipeline Execution

### Using tkn CLI

```bash
# Install tkn CLI (if not installed)
# macOS: brew install tektoncd-cli
# Linux: https://tekton.dev/docs/cli/

# List recent pipeline runs
tkn pipelinerun list -n kitchensink-dev

# Follow logs of latest run
tkn pipelinerun logs -f -n kitchensink-dev --last

# Describe specific run
tkn pipelinerun describe kitchensink-run-abc123 -n kitchensink-dev

# Cancel a running pipeline
tkn pipelinerun cancel kitchensink-run-abc123 -n kitchensink-dev
```

### Using oc CLI

```bash
# List pipeline runs
oc get pipelinerun -n kitchensink-dev

# Watch status
watch oc get pipelinerun -n kitchensink-dev

# Get logs of specific task
oc logs -f -n kitchensink-dev \
  $(oc get pods -n kitchensink-dev -l tekton.dev/task=maven-build -o name | head -1)

# Describe pipeline run
oc describe pipelinerun kitchensink-run-abc123 -n kitchensink-dev
```

### Using Web Console

1. OpenShift Console → Pipelines → kitchensink-dev namespace
2. View pipeline runs in "Pipeline Runs" tab
3. Click on specific run for detailed view with logs
4. See visual pipeline graph with step status

## Customization

### Adding Tests

Insert a test task after maven-build:

```yaml
- name: maven-test
  taskRef:
    name: maven
    kind: ClusterTask
  runAfter:
    - maven-build
  params:
    - name: GOALS
      value: ["test"]
    - name: CONTEXT_DIR
      value: $(params.path-context)
  workspaces:
    - name: source
      workspace: shared-workspace
    - name: maven-settings
      workspace: maven-settings
```

### Adding Security Scanning

Use Trivy or other scanners:

```yaml
- name: scan-image
  taskRef:
    name: trivy-scanner
    kind: Task
  runAfter:
    - build-image
  params:
    - name: IMAGE
      value: $(params.image-name):$(params.git-revision)
    - name: SEVERITY
      value: "CRITICAL,HIGH"
  workspaces:
    - name: source
      workspace: shared-workspace
```

### Adding Notifications

Send Slack notification on completion:

```yaml
finally:
  - name: notify-slack
    taskRef:
      name: send-to-webhook-slack
      kind: Task
    params:
      - name: webhook-secret
        value: slack-webhook-secret
      - name: message
        value: "Pipeline $(context.pipelineRun.name) completed with status $(tasks.status)"
```

## Troubleshooting

### Pipeline Fails at maven-build

**Symptom**: "OutOfMemoryError" or Maven hangs

**Solution**:
```yaml
# Increase memory in maven task
- name: maven-build
  taskRef:
    name: maven
  params:
    - name: MAVEN_ARGS
      value: ["-Dmaven.repo.local=$(workspaces.maven-settings.path)", "-Xmx1g"]
```

### Pipeline Fails at push-image

**Symptom**: "authentication required"

**Solution**:
```bash
# Verify registry secret exists
oc get secret quay-credentials -n kitchensink-dev

# Link secret to pipeline service account
oc secrets link pipeline quay-credentials -n kitchensink-dev

# Test authentication manually
podman login quay.io --username YOUR_USER --password YOUR_TOKEN
```

### EventListener Not Receiving Webhooks

**Symptom**: GitHub shows webhook failed

**Solution**:
```bash
# Check EventListener is running
oc get pods -n kitchensink-dev -l eventlistener=kitchensink-listener

# Check route exists
oc get route el-kitchensink-listener -n kitchensink-dev

# Test webhook manually
curl -X POST https://$(oc get route el-kitchensink-listener -n kitchensink-dev -o jsonpath='{.spec.host}') \
  -H "Content-Type: application/json" \
  -d '{"repository":{"clone_url":"https://github.com/user/repo"},"after":"abc123"}'
```

## Resources

- [Tekton Documentation](https://tekton.dev/docs/)
- [OpenShift Pipelines](https://docs.openshift.com/pipelines/latest/)
- [Tekton Catalog (ClusterTasks)](https://hub.tekton.dev/)
- [Tekton Triggers](https://tekton.dev/docs/triggers/)
