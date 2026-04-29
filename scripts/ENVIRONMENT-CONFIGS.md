# Environment Configurations

Quick reference for switching between CRC and Production settings.

## Quick Switch Commands

### For CRC (OpenShift Local)
```bash
./optimize-for-crc.sh
git add -A && git commit -m "Optimize for CRC"
git push
```

### For Production OpenShift
```bash
./restore-production-defaults.sh
git add -A && git commit -m "Restore production defaults"
git push
```

## Resource Comparison

### DevSpaces

| Setting | Production | CRC |
|---------|-----------|-----|
| Tools Memory | 3Gi | 2Gi |
| Tools CPU | 2000m | 1000m |
| EAP Memory | 2Gi | 1.5Gi |
| EAP CPU | 1000m | 750m |
| Max Workspaces | 5 | 3 |
| Concurrent Workspaces | 3 | 1 |
| PVC Size | 10Gi | 5Gi |
| Metrics Enabled | Yes | No |

### Kitchensink Application

| Setting | Production | CRC |
|---------|-----------|-----|
| Memory Request | 512Mi | 256Mi |
| Memory Limit | 1Gi | 768Mi |
| CPU Request | 250m | 100m |
| CPU Limit | 500m | 500m |

### Maven Cache

| Setting | Production | CRC |
|---------|-----------|-----|
| Volume Size | 3Gi | 3Gi (same) |

## Performance Expectations

### CRC
- **Installation**: 20-30 minutes
- **Workspace Startup**: 2-3 minutes
- **First Maven Build**: 10-15 minutes
- **Hot-Reload**: 3-8 seconds
- **Pipeline Run**: 8-10 minutes

### Production OpenShift (AWS/Azure)
- **Installation**: 10-15 minutes
- **Workspace Startup**: 60-90 seconds
- **First Maven Build**: 5-7 minutes
- **Hot-Reload**: 2-5 seconds
- **Pipeline Run**: 5-6 minutes

## Git Branch Strategy (Alternative Approach)

Instead of switching files, you can use Git branches:

### Option 1: Branch per Environment

```bash
# Create CRC branch
git checkout -b crc
./optimize-for-crc.sh
git add -A && git commit -m "CRC optimizations"
git push -u origin crc

# Create production branch
git checkout -b production
./restore-production-defaults.sh
git add -A && git commit -m "Production settings"
git push -u origin production

# Switch between them
git checkout crc      # For CRC
git checkout production  # For production cluster
```

### Option 2: Keep Main with Production, Use CRC Branch

```bash
# Main branch = production (default)
git checkout main
./restore-production-defaults.sh
git add -A && git commit -m "Main branch: production settings"
git push

# CRC branch for testing
git checkout -b crc
./optimize-for-crc.sh
git add -A && git commit -m "CRC optimizations"
git push -u origin crc

# Update ArgoCD to point to correct branch
# In argocd/app-of-apps.yaml:
spec:
  source:
    targetRevision: main      # Or 'crc' for CRC cluster
```

Then when installing:
- **CRC cluster**: Use `crc` branch
- **Production cluster**: Use `main` branch

## Kustomize Overlay Strategy (Advanced)

For more sophisticated environment management, restructure with Kustomize:

```
components/kitchensink/
├── base/                    # Common resources
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── crc/                 # CRC-specific patches
    │   ├── deployment-patch.yaml
    │   └── kustomization.yaml
    └── production/          # Production-specific patches
        ├── deployment-patch.yaml
        └── kustomization.yaml
```

Then in ArgoCD:
```yaml
spec:
  source:
    path: components/kitchensink/overlays/production  # or /crc
```

## Recommended Approach

**For Simplicity**: Use the scripts
- ✅ Easy to understand
- ✅ No Git complexity
- ✅ Quick to switch
- ⚠️ Must remember to commit after switching

**For Multiple Environments**: Use Git branches
- ✅ Clean separation
- ✅ Easy to deploy different configs
- ✅ No risk of mixing configs
- ⚠️ Need to keep branches in sync for code changes

**For Enterprise**: Use Kustomize overlays
- ✅ Industry standard
- ✅ DRY (Don't Repeat Yourself)
- ✅ Easy to add more environments
- ⚠️ More complex initial setup

## Current Setup: Script-Based Switching

Your current setup uses the simple script approach:

1. **Default state**: Production settings (after `restore-production-defaults.sh`)
2. **CRC optimized**: After running `optimize-for-crc.sh`
3. **Switch back**: Run `restore-production-defaults.sh`

## Workflow Examples

### Scenario 1: Test on CRC, Demo on Production

```bash
# 1. Optimize for CRC testing
./optimize-for-crc.sh
git add -A && git commit -m "Testing on CRC"
git push

# 2. Install on CRC
cd bootstrap && ./install.sh

# 3. Test everything works on CRC
# ... test inner-loop, pipelines, etc ...

# 4. Switch to production settings
./restore-production-defaults.sh
git add -A && git commit -m "Ready for production demo"
git push

# 5. Install on production cluster
# (login to production cluster)
cd bootstrap && ./install.sh
```

### Scenario 2: Maintain Both Environments

```bash
# Create CRC branch
git checkout -b crc
./optimize-for-crc.sh
git add -A && git commit -m "CRC config"
git push -u origin crc

# Keep main as production
git checkout main
./restore-production-defaults.sh
git add -A && git commit -m "Production config"
git push

# Install on CRC
git checkout crc
# Update argocd/app-of-apps.yaml targetRevision: crc
cd bootstrap && ./install.sh

# Install on production (different cluster)
git checkout main
# Ensure argocd/app-of-apps.yaml targetRevision: main
cd bootstrap && ./install.sh
```

### Scenario 3: Quick CRC Demo, No Production Cluster

```bash
# Just use CRC, ignore production settings
./optimize-for-crc.sh
git add -A && git commit -m "CRC demo setup"
git push

cd bootstrap && ./install.sh
# Done! Demo on CRC
```

## Verification After Switching

After running either script, verify the changes:

```bash
# Check DevSpaces memory
grep -A5 "name: universal-developer-image" components/devspaces/workspace-config/checluster.yaml

# Check Kitchensink memory
grep -A4 "resources:" components/kitchensink/k8s/deployment.yaml

# Check Devfile
grep "memoryLimit:" components/kitchensink/devfile.yaml

# Or just run verification
./verify-setup.sh
```

## Tips

1. **Always commit after switching**: Don't forget to push to Git after running optimization scripts
2. **Test on CRC first**: Validate the setup on CRC before using on production cluster
3. **Document your choice**: Add a comment in your commit message about which environment it's for
4. **Clean installs**: When switching environments, consider uninstalling first for a clean slate
5. **Resource monitoring**: Watch `oc adm top nodes` especially on CRC to avoid resource exhaustion

## Summary

**Simple workflow** (recommended for getting started):
```bash
./optimize-for-crc.sh          # Optimize for CRC
./restore-production-defaults.sh  # Back to production

# Always commit and push after switching
git add -A && git commit -m "Switch to [CRC|Production]" && git push
```

**You can switch as many times as you want** - the scripts are idempotent and safe to run repeatedly.
