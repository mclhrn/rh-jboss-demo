# Getting Started

Quick guide to set up and deploy the Red Hat JBoss Modernization Demo.

## Prerequisites

- **OpenShift 4.12+** cluster with cluster-admin access
- **oc CLI** installed and authenticated
- **git** installed locally
- **GitHub/GitLab account** for forking the repository
- **Quay.io account** (free tier is fine) for container images

## Step-by-Step Setup

### 1. Fork and Clone the Repository

```bash
# Fork this repository on GitHub (use the Fork button)

# Clone your fork
git clone https://github.com/YOUR_USERNAME/rh-jboss-demo
cd rh-jboss-demo
```

### 2. Download Kitchensink Source Code

Run the setup script to download the official JBoss quickstart:

```bash
./setup-source-code.sh
```

**What this does**:
- Downloads JBoss EAP 7.4 kitchensink quickstart from GitHub
- Copies source code to `components/kitchensink/src/`
- Copies `pom.xml` for Maven builds
- Creates Developer Hub template skeleton
- Sets up `catalog-info.yaml`

**Time**: ~30 seconds

### 3. Update Repository URLs

Replace all `CHANGEME` placeholders with your GitHub username:

```bash
# Quick replace all at once
find . -type f \( -name "*.yaml" -o -name "*.md" \) -exec sed -i '' 's/CHANGEME/YOUR_USERNAME/g' {} \;

# Or on Linux (without the empty string after -i)
find . -type f \( -name "*.yaml" -o -name "*.md" \) -exec sed -i 's/CHANGEME/YOUR_USERNAME/g' {} \;
```

**Verify the changes**:
```bash
grep -r "CHANGEME" --include="*.yaml" .
# Should return no results
```

### 4. Update Quay.io Registry

Update registry organization in pipeline and deployment files:

```bash
# Replace YOUR_QUAY_ORG with your Quay.io organization/username
find . -type f -name "*.yaml" -exec sed -i '' 's/quay.io\/CHANGEME/quay.io\/YOUR_QUAY_ORG/g' {} \;
```

### 5. Commit and Push Changes

```bash
git add .
git commit -m "Configure demo for my environment"
git push origin main
```

### 6. Install on OpenShift

**Login to your cluster**:
```bash
oc login https://api.your-cluster.com:6443
```

**Run the installer**:
```bash
cd bootstrap
./install.sh
```

**Monitor installation**:
```bash
# In another terminal
watch -n 5 './install.sh --status'
```

**Installation time**: 8-15 minutes

### 7. Get Access URLs

```bash
./install.sh --urls
```

**You'll get**:
- ArgoCD Console URL + credentials
- Developer Hub URL
- DevSpaces URL
- Kitchensink Application URL

### 8. Configure Registry Credentials (for CI/CD)

For the Tekton pipeline to push images to Quay.io:

```bash
# Create Quay.io credentials secret
oc create secret docker-registry quay-credentials \
  --docker-server=quay.io \
  --docker-username=YOUR_QUAY_USERNAME \
  --docker-password=YOUR_QUAY_PASSWORD \
  -n kitchensink-dev

# Link to pipeline service account
oc secrets link pipeline quay-credentials -n kitchensink-dev --for=pull,mount
```

### 9. Configure GitHub Token (for Developer Hub)

For Developer Hub to create repositories:

```bash
# Create GitHub personal access token at:
# https://github.com/settings/tokens/new
# Required scopes: repo, workflow

# Create secret in RHDH namespace
oc create secret generic github-credentials \
  --from-literal=GITHUB_TOKEN=ghp_your_token_here \
  -n rhdh

# Restart Developer Hub to pick up the secret
oc rollout restart deployment backstage -n rhdh
```

## Verification

### Test 1: DevSpaces Hot-Reload

```bash
# Get DevSpaces URL
DEVSPACES_URL=$(oc get route devspaces -n openshift-devspaces -o jsonpath='{.spec.host}')

# Open workspace
echo "Open: https://${DEVSPACES_URL}/#https://github.com/YOUR_USERNAME/rh-jboss-demo"
```

In the workspace:
1. Terminal: `cd components/kitchensink`
2. Build: `mvn clean package` (first time takes 5-7 min)
3. Start: `mvn wildfly:run -Dwildfly.dev`
4. Edit: `src/main/webapp/index.xhtml`
5. Verify hot-reload works (should take ~3 seconds)

**Expected**: Changes appear in seconds, not minutes

### Test 2: Pipeline Execution

```bash
# Manually trigger the pipeline
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
      value: quay.io/YOUR_QUAY_ORG/kitchensink
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
tkn pipelinerun logs -f -n kitchensink-dev --last
```

**Expected**: Pipeline completes in 5-8 minutes

### Test 3: ArgoCD Sync

```bash
# Check ArgoCD application status
oc get application kitchensink -n openshift-gitops

# Should show:
# SYNC STATUS: Synced
# HEALTH STATUS: Healthy
```

### Test 4: Application is Running

```bash
# Get application URL
KITCHENSINK_URL=$(oc get route kitchensink -n kitchensink-dev -o jsonpath='{.spec.host}')

# Test the app
curl -I http://${KITCHENSINK_URL}
# Should return: HTTP/1.1 200 OK

# Open in browser
echo "Open: http://${KITCHENSINK_URL}"
```

**Expected**: See the kitchensink UI, able to register members

## Troubleshooting

### Issue: Installation Stuck

**Check operator status**:
```bash
oc get csv -A | grep -E "gitops|pipelines|devspaces|backstage"
```

All should show `Succeeded`.

**Check ArgoCD applications**:
```bash
oc get applications -n openshift-gitops
```

If stuck, check individual app:
```bash
oc describe application kitchensink -n openshift-gitops
```

### Issue: Pipeline Fails at "push-image"

**Cause**: Missing or incorrect registry credentials

**Fix**:
```bash
# Delete old secret
oc delete secret quay-credentials -n kitchensink-dev

# Recreate with correct credentials
oc create secret docker-registry quay-credentials \
  --docker-server=quay.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PASSWORD \
  -n kitchensink-dev

# Link to pipeline
oc secrets link pipeline quay-credentials -n kitchensink-dev
```

### Issue: DevSpaces Workspace Won't Start

**Check pod status**:
```bash
oc get pods -n YOUR_USERNAME-devspaces
```

**Check logs**:
```bash
oc logs -n YOUR_USERNAME-devspaces <pod-name>
```

**Common fix**: Delete and recreate workspace

### Issue: Hot-Reload Not Working

**Ensure you started with `-Dwildfly.dev`**:
```bash
# Wrong (no hot-reload)
mvn wildfly:run

# Correct (with hot-reload)
mvn wildfly:run -Dwildfly.dev
```

### Issue: Developer Hub Can't Create Repos

**Check GitHub token**:
```bash
# Verify secret exists
oc get secret github-credentials -n rhdh

# Test token manually
curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/user
```

**Recreate if needed**:
```bash
oc delete secret github-credentials -n rhdh
oc create secret generic github-credentials \
  --from-literal=GITHUB_TOKEN=ghp_new_token \
  -n rhdh
oc rollout restart deployment backstage -n rhdh
```

## Next Steps

### Run the Demo

See `docs/DEMO-SCRIPT.md` for the complete demo narrative with talking points.

Key sections:
1. **Inner-loop**: Show hot-reload (10 min)
2. **Developer onboarding**: Use Developer Hub templates (5 min)
3. **CI/CD**: Show pipeline and GitOps (10 min)

### Try Inner-Loop Development

See `docs/INNER-LOOP.md` for hands-on guide comparing:
- Old workflow: 5 minutes per change
- New workflow: 5 seconds per change

### Customize for Your Needs

1. **Add your own application**: Replace kitchensink with your JBoss app
2. **Customize pipeline**: Add security scanning, additional tests
3. **Multi-environment**: Set up dev, staging, prod with Kustomize overlays
4. **Add monitoring**: Integrate Prometheus, Grafana

## Uninstallation

To remove all demo components:

```bash
cd bootstrap
./install.sh --uninstall
```

This will:
- Delete all ArgoCD applications
- Remove deployed workloads
- Optionally remove operators
- Clean up namespaces

## Support

- **Issues**: https://github.com/YOUR_USERNAME/rh-jboss-demo/issues
- **Documentation**: See README files in each component directory
- **JBoss EAP Docs**: https://access.redhat.com/documentation/en-us/red_hat_jboss_enterprise_application_platform/

## Quick Reference

### Essential URLs

```bash
# Get all URLs
cd bootstrap
./install.sh --urls
```

### Essential Commands

```bash
# Check status
./bootstrap/install.sh --status

# View pipeline runs
tkn pipelinerun list -n kitchensink-dev

# View ArgoCD apps
oc get applications -n openshift-gitops

# View DevSpaces pods
oc get pods -n openshift-devspaces

# View kitchensink app
oc get pods -n kitchensink-dev
```

### Logs

```bash
# DevSpaces logs
oc logs -n openshift-devspaces -l app=che

# Pipeline logs
tkn pipelinerun logs -f -n kitchensink-dev --last

# ArgoCD logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-server

# Kitchensink app logs
oc logs -n kitchensink-dev deployment/kitchensink
```

Happy demo-ing! 🚀
