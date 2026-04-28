# OpenShift DevSpaces Component

This component deploys OpenShift DevSpaces (formerly CodeReady Workspaces), providing browser-based development environments with pre-configured JBoss EAP tooling.

## Overview

OpenShift DevSpaces solves the **5-minute inner-loop problem** by providing:

- **Instant development environments**: No local setup required
- **Hot-reload enabled**: Changes appear in seconds, not minutes
- **Pre-configured tooling**: JBoss EAP, Maven, Java debugging ready to go
- **Consistent environments**: Everyone gets the same setup
- **Resource efficient**: Workspaces run on the cluster, not local machines

## What Gets Deployed

### 1. DevSpaces Operator

```yaml
components/devspaces/operator/subscription.yaml
```

**Purpose**: Installs the OpenShift DevSpaces operator cluster-wide

**Resources**:
- Subscription to `devspaces` operator from Red Hat catalog
- Installs into `openshift-operators` namespace
- Manages DevSpaces custom resources across all namespaces

**Installation Time**: 2-3 minutes

### 2. CheCluster Instance

```yaml
components/devspaces/workspace-config/checluster.yaml
```

**Purpose**: Creates the actual DevSpaces server instance

**Resources**:
- CheCluster custom resource in `openshift-devspaces` namespace
- DevSpaces dashboard web UI
- Workspace controllers and plugins
- Container registry for workspace images

**Installation Time**: 5-7 minutes

**Configuration Highlights**:
```yaml
spec:
  devEnvironments:
    storage:
      pvcStrategy: per-workspace  # Dedicated PVC per workspace
    defaultEditor: che-incubator/che-code/latest  # VS Code in browser
    defaultNamespace:
      autoProvision: true  # Auto-create user workspaces
    containerBuildConfiguration:
      openShiftSecurityContextConstraint: container-build  # Allow builds
```

### 3. Workspace Configuration

```yaml
components/devspaces/workspace-config/devfile-registry.yaml
```

**Purpose**: Registers custom devfiles (workspace definitions) for JBoss

**Contains**:
- JBoss EAP devfile with hot-reload
- Maven configuration
- Java debugging setup
- Sample projects

## DevSpaces Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  OpenShift DevSpaces                         │
│                                                              │
│  ┌──────────────────────────────────────────────┐          │
│  │  DevSpaces Dashboard (Web UI)                │          │
│  │  - Workspace management                      │          │
│  │  - User preferences                          │          │
│  │  - Sample projects                           │          │
│  └──────────────────────────────────────────────┘          │
│                       │                                      │
│                       │ Creates workspaces                  │
│                       ▼                                      │
│  ┌──────────────────────────────────────────────┐          │
│  │  User Workspace (Namespace)                  │          │
│  │                                               │          │
│  │  ┌────────────────────────────────┐          │          │
│  │  │  IDE Container                 │          │          │
│  │  │  - VS Code (browser)           │          │          │
│  │  │  - JBoss EAP tools             │          │          │
│  │  │  - Git, Maven                  │          │          │
│  │  └────────────────────────────────┘          │          │
│  │                                               │          │
│  │  ┌────────────────────────────────┐          │          │
│  │  │  Runtime Container             │          │          │
│  │  │  - JBoss EAP server            │          │          │
│  │  │  - Application code            │          │          │
│  │  │  - Hot-reload enabled          │          │          │
│  │  └────────────────────────────────┘          │          │
│  │                                               │          │
│  │  ┌────────────────────────────────┐          │          │
│  │  │  Persistent Volume              │          │          │
│  │  │  - Source code                 │          │          │
│  │  │  - Maven cache                 │          │          │
│  │  └────────────────────────────────┘          │          │
│  └──────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────┘
                       │
                       │ Exposed via Route
                       ▼
              User's Web Browser
          (VS Code interface + running app)
```

## Workspace Configuration (Devfile)

The kitchensink application includes a devfile at `components/kitchensink/devfile.yaml` that defines the development environment.

### Key Devfile Sections

#### 1. Metadata

```yaml
metadata:
  name: jboss-eap-kitchensink
  displayName: JBoss EAP Kitchensink
  description: JBoss EAP development with hot-reload
  tags: ["Java", "JBoss", "EAP", "Maven"]
  projectType: "jboss-eap"
  language: "Java"
  version: 2.2.0
```

#### 2. Components

**IDE Container** (VS Code in browser):
```yaml
- name: tools
  container:
    image: quay.io/devfile/universal-developer-image:latest
    memoryLimit: 3Gi
    cpuLimit: 2000m
    endpoints:
      - name: ide
        targetPort: 3100
        exposure: public
        protocol: https
```

**JBoss EAP Runtime**:
```yaml
- name: eap
  container:
    image: registry.redhat.io/jboss-eap-7/eap74-openjdk11-openshift-rhel8:latest
    memoryLimit: 2Gi
    cpuLimit: 1000m
    env:
      - name: MAVEN_OPTS
        value: "-Xmx1g"
    endpoints:
      - name: jboss
        targetPort: 8080
        exposure: public
        protocol: http
    volumeMounts:
      - name: m2
        path: /home/jboss/.m2
```

#### 3. Commands

**Build Command**:
```yaml
- id: build
  exec:
    component: tools
    commandLine: mvn clean package -DskipTests
    workingDir: ${PROJECT_SOURCE}
    group:
      kind: build
      isDefault: true
```

**Run with Hot-Reload**:
```yaml
- id: run-hot-reload
  exec:
    component: eap
    commandLine: |
      mvn wildfly:run \
        -Dwildfly.hostname=0.0.0.0 \
        -Dwildfly.port=8080 \
        -Dwildfly.dev
    workingDir: ${PROJECT_SOURCE}
    group:
      kind: run
      isDefault: true
```

**Debug**:
```yaml
- id: debug
  exec:
    component: eap
    commandLine: |
      mvn wildfly:run \
        -Dwildfly.javaOpts="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005" \
        -Dwildfly.hostname=0.0.0.0 \
        -Dwildfly.dev
    workingDir: ${PROJECT_SOURCE}
    group:
      kind: debug
```

#### 4. Starter Projects

```yaml
starterProjects:
  - name: kitchensink
    git:
      remotes:
        origin: https://github.com/YOUR_USERNAME/rh-jboss-demo.git
      checkoutFrom:
        revision: main
    subDir: components/kitchensink
```

## How Hot-Reload Works

DevSpaces achieves the **seconds vs minutes** improvement through:

### 1. Maven WildFly Plugin Dev Mode

```bash
mvn wildfly:run -Dwildfly.dev
```

**What it does**:
- Starts JBoss in development mode
- Watches source files for changes
- Automatically recompiles and redeploys on save
- No server restart required for most changes

### 2. Synchronized File System

```
Developer edits in browser → File saved in workspace PVC → Maven watches PVC
  → Recompile → Hot-swap classes → App updated (2-5 seconds)
```

**Contrast with traditional Eclipse + WebSphere**:
```
Developer edits in Eclipse → Save → Eclipse republish → WebSphere detect
  → Undeploy old → Deploy new → Restart app (5+ minutes)
```

### 3. Persistent Workspace State

- Maven dependencies cached in PVC (first build is slow, subsequent builds are fast)
- Workspace survives browser close (come back later, pick up where you left off)
- No "clean my workspace" issues

## Usage

### Starting a Workspace

#### Option 1: From DevSpaces Dashboard

1. Get the DevSpaces URL:
   ```bash
   oc get route devspaces -n openshift-devspaces -o jsonpath='{.spec.host}'
   ```

2. Open in browser and log in with OpenShift credentials

3. Click "Create Workspace"

4. Select "Import from Git"

5. Enter repository URL:
   ```
   https://github.com/YOUR_USERNAME/rh-jboss-demo
   ```

6. DevSpaces auto-detects the devfile and creates the workspace

#### Option 2: Direct URL (Faster)

```bash
# Get DevSpaces URL
DEVSPACES_URL=$(oc get route devspaces -n openshift-devspaces -o jsonpath='{.spec.host}')

# Get your Git repo URL
GIT_REPO="https://github.com/YOUR_USERNAME/rh-jboss-demo"

# Open in browser
echo "https://${DEVSPACES_URL}/#${GIT_REPO}"
```

This URL automatically creates a workspace from the Git repo.

### Making Code Changes with Hot-Reload

1. **Open the workspace** (takes 30-60 seconds to start)

2. **Start the JBoss server**:
   - Press `F1` or `Cmd+Shift+P`
   - Type "Tasks: Run Task"
   - Select "run-hot-reload"
   - Server starts in terminal (takes ~30 seconds first time)

3. **Open the running app**:
   - Click the "Open in Browser" notification
   - Or find the URL in the terminal output

4. **Make a change**:
   - Edit `src/main/webapp/index.xhtml`
   - Change a heading or text
   - Save the file (`Cmd+S` or `Ctrl+S`)

5. **See the change**:
   - Refresh the app browser tab
   - Change appears in 2-5 seconds

### Comparing to Traditional Workflow

**Demo Script**:

1. **"Here's the old way"** (explain verbally, don't demo):
   - Eclipse with WebSphere plugin
   - Edit file
   - Wait for auto-publish (1-2 minutes)
   - Wait for WebSphere to detect change (1 minute)
   - Wait for redeploy (2-3 minutes)
   - Total: ~5 minutes per change

2. **"Here's the new way"** (live demo in DevSpaces):
   - Edit `index.xhtml` in browser IDE
   - Save
   - Refresh app browser
   - Total: 3-5 seconds

3. **Calculate time savings**:
   - Developer makes ~50 code changes per day
   - Old way: 50 × 5 min = 250 minutes (4+ hours) waiting
   - New way: 50 × 5 sec = 250 seconds (4 minutes) waiting
   - **Savings: 4 hours per developer per day**

## Customization

### Adjusting Resource Limits

Edit `components/devspaces/workspace-config/checluster.yaml`:

```yaml
spec:
  devEnvironments:
    defaultComponents:
      - name: universal-developer-image
        container:
          memoryLimit: 4Gi      # Increase for large projects
          memoryRequest: 2Gi
          cpuLimit: 2000m
          cpuRequest: 1000m
```

### Adding JBoss Extensions/Plugins

Edit the devfile to add VS Code extensions:

```yaml
components:
  - name: vscode-java-extensions
    plugin:
      kubernetes:
        name: vscode-java
        namespace: devfile-registry
```

Or install manually in workspace:
- Extensions → Search "JBoss" → Install

### Persistent Storage Configuration

Change storage strategy in `checluster.yaml`:

```yaml
spec:
  devEnvironments:
    storage:
      pvcStrategy: per-workspace  # One PVC per workspace (default)
      # OR
      pvcStrategy: common         # Shared PVC (all workspaces)
      # OR
      pvcStrategy: ephemeral      # No persistence (lost on restart)
      
      # Storage class and size
      pvcStorageClassName: gp3    # AWS, adjust for your cloud
      perWorkspacePVCSize: 10Gi   # Size per workspace
```

### Configuring Private Git Repositories

For private repos, configure Git credentials:

```yaml
# In devfile
components:
  - name: git-credentials
    volume:
      size: 1Mi
    mount:
      path: /home/user/.git-credentials

commands:
  - id: configure-git
    exec:
      component: tools
      commandLine: |
        git config --global credential.helper store
        echo "https://USER:TOKEN@github.com" > ~/.git-credentials
```

Or use OpenShift secrets:

```bash
oc create secret generic git-credentials \
  -n openshift-devspaces \
  --from-literal=username=YOUR_USERNAME \
  --from-literal=password=YOUR_TOKEN

oc label secret git-credentials \
  controller.devfile.io/git-credential=true
```

## Troubleshooting

### Workspace Won't Start

**Symptom**: Workspace stuck in "Starting" state

**Diagnosis**:
```bash
# Find your workspace pod
oc get pods -n $USER-devspaces

# Check pod logs
oc logs -n $USER-devspaces $POD_NAME
```

**Common Causes**:
- Insufficient cluster resources (CPU/memory)
- Image pull errors
- PVC mount issues

**Solution**:
```bash
# Check cluster capacity
oc adm top nodes

# Check for events
oc get events -n $USER-devspaces --sort-by='.lastTimestamp'

# Delete and recreate workspace
```

### Hot-Reload Not Working

**Symptom**: Code changes don't reflect in running app

**Diagnosis**:
1. Check Maven is running in dev mode:
   ```bash
   ps aux | grep wildfly.dev
   ```

2. Check file watcher is active:
   ```bash
   # In workspace terminal
   mvn wildfly:run -Dwildfly.dev -X  # Verbose mode
   ```

**Common Causes**:
- Maven not in dev mode (missing `-Dwildfly.dev`)
- File system permissions
- Changes to files that require restart (pom.xml, persistence.xml)

**Solution**:
- Restart with: `mvn wildfly:run -Dwildfly.dev`
- For `pom.xml` changes, restart is required
- Check file is actually saved (look for save indicator)

### Can't Access Running Application

**Symptom**: Endpoint URL returns 404 or connection refused

**Diagnosis**:
```bash
# Check JBoss is listening
curl localhost:8080

# Check endpoint is exposed
oc get endpoints -n $USER-devspaces
```

**Common Causes**:
- JBoss server not started
- Endpoint not exposed in devfile
- Route not created

**Solution**:
- Ensure `run-hot-reload` task is running
- Check `endpoints` in devfile.yaml
- Restart workspace if needed

### Slow First Build

**Symptom**: Initial `mvn package` takes 5-10 minutes

**Diagnosis**: This is expected! Maven is downloading all dependencies.

**Solution**:
- Be patient on first build
- Subsequent builds use cached dependencies (~30 seconds)
- Consider pre-populating Maven cache in workspace image

### Out of Memory Errors

**Symptom**: "OutOfMemoryError" in workspace terminal

**Diagnosis**:
```bash
# Check workspace resource limits
oc describe pod $WORKSPACE_POD -n $USER-devspaces | grep -A 5 Limits
```

**Solution**:
- Increase memory in devfile:
  ```yaml
  - name: eap
    container:
      memoryLimit: 3Gi  # Increase from 2Gi
  ```
- Or adjust `MAVEN_OPTS`:
  ```yaml
  env:
    - name: MAVEN_OPTS
      value: "-Xmx1536m"  # Reduce heap size
  ```

## Validation

After deployment, verify DevSpaces is working:

```bash
# Check operator is running
oc get csv -n openshift-operators | grep devspaces

# Check CheCluster is ready
oc get checluster -n openshift-devspaces

# Check DevSpaces server pods
oc get pods -n openshift-devspaces

# Get DevSpaces URL
oc get route devspaces -n openshift-devspaces -o jsonpath='{.spec.host}'

# Create test workspace
DEVSPACES_URL=$(oc get route devspaces -n openshift-devspaces -o jsonpath='{.spec.host}')
echo "Open: https://${DEVSPACES_URL}/#https://github.com/YOUR_USERNAME/rh-jboss-demo"
```

## Resources

- [OpenShift DevSpaces Documentation](https://docs.openshift.com/devspaces/latest/)
- [Devfile Specification](https://devfile.io/)
- [WildFly Maven Plugin Dev Mode](https://docs.wildfly.org/wildfly-maven-plugin/dev-mojo.html)
- [CheCluster API Reference](https://eclipse.dev/che/docs/stable/administration-guide/configuring-devspaces/)
