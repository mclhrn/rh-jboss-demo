# OpenShift Local (CRC) Setup Guide

Special instructions for running this demo on OpenShift Local (formerly CodeReady Containers).

## CRC Configuration

### Minimum Requirements

- **CPUs**: 6 cores minimum (8 recommended)
- **Memory**: 16GB minimum (20GB recommended for better performance)
- **Disk**: 80GB minimum
- **Host OS**: macOS, Windows, or Linux with virtualization enabled

### Configure CRC

```bash
# Stop CRC if running
crc stop

# Configure resources
crc config set cpus 6
crc config set memory 16384  # 16GB
crc config set disk-size 80

# Optional: Enable monitoring (uses more resources but helpful)
crc config set enable-cluster-monitoring false  # Disable to save resources

# Start CRC
crc start
```

**Startup time**: 5-10 minutes on first start

### Login to CRC

```bash
# Use credentials from CRC output
eval $(crc oc-env)
oc login -u kubeadmin https://api.crc.testing:6443
```

## CRC-Optimized Component Configuration

CRC has limited resources, so we'll reduce resource requests/limits:

### 1. DevSpaces Configuration

**Edit**: `components/devspaces/workspace-config/checluster.yaml`

```yaml
spec:
  devEnvironments:
    defaultComponents:
      - name: universal-developer-image
        container:
          memoryLimit: 2Gi      # Reduced from 3Gi
          memoryRequest: 1Gi    # Added explicit request
          cpuLimit: 1000m       # Reduced from 2000m
          cpuRequest: 500m      # Added explicit request
    storage:
      pvcStrategy: per-workspace
      perWorkspacePVCSize: 5Gi  # Reduced from 10Gi
```

### 2. Kitchensink Deployment

**Edit**: `components/kitchensink/k8s/deployment.yaml`

```yaml
resources:
  requests:
    memory: "256Mi"   # Reduced from 512Mi
    cpu: "100m"       # Reduced from 250m
  limits:
    memory: "768Mi"   # Reduced from 1Gi
    cpu: "500m"       # Same as before
```

### 3. DevSpaces Devfile

**Edit**: `components/kitchensink/devfile.yaml`

```yaml
components:
  - name: tools
    container:
      memoryLimit: 2Gi    # Reduced from 3Gi
      cpuLimit: 1000m     # Reduced from 2000m

  - name: eap
    container:
      memoryLimit: 1536Mi # Reduced from 2Gi
      cpuLimit: 750m      # Reduced from 1000m
```

### 4. Developer Hub (Optional - Can Skip on CRC)

Developer Hub is resource-intensive. For CRC demo, you can skip it:

**Option 1: Skip Developer Hub**

Edit `argocd/applications/developer-hub.yaml` and add:
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
spec:
  syncPolicy:
    automated: null  # Disable auto-sync
```

Then manually delete from ArgoCD after installation:
```bash
oc delete application developer-hub -n openshift-gitops
```

**Option 2: Keep it but expect slower startup** (~5-7 minutes)

## CRC Storage Class

CRC uses `crc-csi-hostpath-provisioner` as the default storage class. This is already configured and works automatically.

**Verify**:
```bash
oc get storageclass
# Should show: crc-csi-hostpath-provisioner (default)
```

## Installation on CRC

### Step 1: Apply CRC Optimizations

Run this script to apply all CRC optimizations:

```bash
#!/bin/bash
# Apply CRC resource optimizations

# DevSpaces
cat > components/devspaces/workspace-config/checluster.yaml <<'EOF'
apiVersion: org.eclipse.che/v2
kind: CheCluster
metadata:
  name: devspaces
  namespace: openshift-devspaces
spec:
  components:
    cheServer:
      debug: false
      logLevel: INFO
    metrics:
      enable: false  # Disable to save resources
    pluginRegistry:
      openVSXURL: https://open-vsx.org
    devfileRegistry:
      externalDevfileRegistries:
        - url: https://registry.devfile.io
  containerRegistry: {}
  devEnvironments:
    startTimeoutSeconds: 600
    secondsOfRunBeforeIdling: -1
    maxNumberOfWorkspacesPerUser: 3      # Reduced from 5
    maxNumberOfRunningWorkspacesPerUser: 1  # Only 1 running at a time
    containerBuildConfiguration:
      openShiftSecurityContextConstraint: container-build
    defaultEditor: che-incubator/che-code/latest
    defaultNamespace:
      autoProvision: true
      template: <username>-devspaces
    defaultComponents:
      - name: universal-developer-image
        container:
          image: quay.io/devfile/universal-developer-image:latest
          memoryLimit: 2Gi
          memoryRequest: 1Gi
          cpuLimit: 1000m
          cpuRequest: 500m
    storage:
      pvcStrategy: per-workspace
      perWorkspacePVCSize: 5Gi
  networking:
    auth:
      gateway:
        configLabels:
          app: che
          component: che-gateway-config
EOF

echo "✓ DevSpaces optimized for CRC"

# Kitchensink deployment
sed -i '' 's/memory: "512Mi"/memory: "256Mi"/g' components/kitchensink/k8s/deployment.yaml
sed -i '' 's/cpu: "250m"/cpu: "100m"/g' components/kitchensink/k8s/deployment.yaml
sed -i '' 's/memory: "1Gi"/memory: "768Mi"/g' components/kitchensink/k8s/deployment.yaml

echo "✓ Kitchensink deployment optimized for CRC"

# Devfile
sed -i '' 's/memoryLimit: 3Gi/memoryLimit: 2Gi/g' components/kitchensink/devfile.yaml
sed -i '' 's/cpuLimit: 2000m/cpuLimit: 1000m/g' components/kitchensink/devfile.yaml
sed -i '' 's/memoryLimit: 2Gi/memoryLimit: 1536Mi/g' components/kitchensink/devfile.yaml

echo "✓ Devfile optimized for CRC"

echo ""
echo "All CRC optimizations applied!"
```

Save as `apply-crc-optimizations.sh` and run:
```bash
chmod +x apply-crc-optimizations.sh
./apply-crc-optimizations.sh
```

### Step 2: Standard Installation

```bash
cd bootstrap
./install.sh
```

### Step 3: Monitor Resource Usage

```bash
# Watch node resources
watch oc adm top nodes

# Watch pod resources
watch oc adm top pods --all-namespaces
```

## Expected Behavior on CRC

### Installation Timeline

- **Operators**: 3-5 minutes each (slower than production OpenShift)
- **DevSpaces**: 7-10 minutes to fully start
- **Developer Hub**: 5-7 minutes (if you keep it)
- **Kitchensink**: 2-3 minutes
- **Total**: 20-30 minutes (vs 10-15 on production cluster)

### Performance Expectations

- **First Maven build**: 10-15 minutes (downloading dependencies)
- **Subsequent builds**: 1-2 minutes
- **Hot-reload**: 3-8 seconds (vs 2-5 on production)
- **Workspace startup**: 2-3 minutes (vs 60-90 seconds on production)

### What Works Well on CRC

✅ **Inner-loop development** - DevSpaces hot-reload works great  
✅ **Pipeline execution** - Tekton works, just slower  
✅ **ArgoCD GitOps** - Full functionality  
✅ **Basic demo flow** - All core features work  

### What's Slower on CRC

⚠️ **Workspace startup** - Slower due to image pulls and resource constraints  
⚠️ **First build** - Maven dependency download takes longer  
⚠️ **Multiple concurrent operations** - Limited CPU affects parallel tasks  
⚠️ **Developer Hub** - Resource-intensive, slower response  

### What to Skip on CRC

❌ **Multiple DevSpaces workspaces** - Stick to one at a time  
❌ **Multiple pipeline runs** - Wait for one to complete before starting another  
❌ **Load testing** - CRC is single-node, not for performance testing  

## CRC-Specific Troubleshooting

### Issue: Pods Stuck in Pending

**Cause**: Insufficient resources

**Check**:
```bash
oc get pods --all-namespaces | grep Pending
oc describe pod <pod-name> -n <namespace>
# Look for "Insufficient cpu" or "Insufficient memory"
```

**Fix**:
```bash
# Increase CRC resources
crc stop
crc config set memory 20480  # 20GB
crc config set cpus 8
crc start
```

### Issue: DevSpaces Workspace Won't Start

**Cause**: Not enough resources for workspace

**Fix**: Only run one workspace at a time
```bash
# Delete any other running workspaces
oc get pods -A | grep workspace
oc delete pod <workspace-pod> -n <workspace-namespace>
```

### Issue: Pipeline OOMKilled

**Cause**: Maven build exceeding memory limits

**Fix**: Increase pipeline task memory
```bash
# Edit the running PipelineRun
oc edit pipelinerun <run-name> -n kitchensink-dev

# Or just retry - sometimes it works on second attempt
```

### Issue: CRC Running Out of Disk Space

**Check disk usage**:
```bash
crc status
# Shows disk usage
```

**Clean up**:
```bash
# Clean up old container images
oc adm prune images --confirm

# Clean up old pipeline runs
oc delete pipelinerun --all -n kitchensink-dev

# Clean up old workspace PVCs
oc delete pvc -n <user>-devspaces <old-pvc>
```

## Demo Tips for CRC

### Before Demo

1. **Start CRC 30 minutes early** - Give operators time to settle
2. **Pre-pull images**: Start workspace once, let it fully initialize, then stop
3. **Pre-run pipeline**: Run once so Maven cache is populated
4. **Close unnecessary apps**: Free up host machine resources

### During Demo

1. **Disable screen recording** if possible - saves host CPU
2. **Close other browser tabs** - Especially video/heavy sites
3. **Don't run multiple operations simultaneously** - Wait for each to complete
4. **If something is slow, acknowledge it**: "On a production cluster, this takes 30 seconds. On CRC it's a bit slower, but the workflow is the same."

### Demo Script Adjustments

**Hot-reload demo**:
- Expect 5-8 seconds instead of 2-5 seconds
- Still impressive vs 5 minutes!

**Pipeline demo**:
- Show a completed pipeline run (don't run live)
- Or trigger it but don't wait for completion
- Explain: "This takes 8 minutes on CRC, 5 minutes on production"

**Focus on**:
- The workflow and automation
- The developer experience improvement
- The concept, not the raw speed

## Recommended CRC Demo Flow

### Option 1: Minimal (Fastest on CRC)

**Install only**:
- OpenShift GitOps ✓
- OpenShift Pipelines ✓
- DevSpaces ✓
- Kitchensink ✓
- Skip Developer Hub ✗

**Demo**:
1. Inner-loop with DevSpaces (10 min)
2. Show completed pipeline run (5 min)
3. Show ArgoCD GitOps (5 min)

**Total time**: 20 minutes, no lag

### Option 2: Full (Everything)

**Install everything** - Just expect slower performance

**Demo**:
1. Inner-loop (15 min - give extra time)
2. Developer Hub tour (5 min - walk through UI slowly)
3. CI/CD overview (10 min - show completed runs)

**Total time**: 30 minutes

## Alternative: Use CRC for Development, Cloud Cluster for Demo

**Best practice**:
1. **Develop on CRC**: Test all the configs, fix issues
2. **Demo on AWS/Azure OpenShift**: Better performance for live audience
3. **Use screen recording**: Record demo on production cluster, play back if needed

## Validation Checklist for CRC

After installation, verify:

```bash
# All operators running
oc get csv -A | grep -E "gitops|pipelines|devspaces" | grep Succeeded

# Workloads healthy
oc get pods -n openshift-gitops
oc get pods -n openshift-pipelines  
oc get pods -n openshift-devspaces
oc get pods -n kitchensink-dev

# Routes accessible
oc get routes -A

# Resource usage acceptable
oc adm top nodes
# Should be under 80% CPU/memory
```

## CRC-Specific Installation Command

```bash
# Install with CRC awareness
cd bootstrap
./install.sh

# If you see timeout errors, that's normal on CRC
# Just wait longer and check status
./install.sh --status
```

## Summary

**CRC is great for**:
- Learning and testing the setup
- Developing the demo content
- Understanding the architecture
- Small-scale demos to individuals

**CRC limitations**:
- Slower performance (but workflow is the same)
- Single-node (no HA, no scaling demos)
- Resource-constrained (limit concurrent operations)

**Recommendation**: 
- ✅ Use CRC to validate the setup works
- ✅ Perfect for 1-on-1 demos or small groups
- ⚠️ For large audience/important demos, consider a cloud cluster
- ✅ Always have a backup plan (screen recording of successful run)

Good luck with your CRC setup! Let me know if you hit any CRC-specific issues.
