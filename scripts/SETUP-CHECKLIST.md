# Setup Checklist

Use this checklist to ensure you've completed all setup steps before installing the demo.

## ✅ Pre-Installation Checklist

### 1. Source Code Setup

- [ ] Run `./setup-source-code.sh` to download kitchensink source
- [ ] Verify `components/kitchensink/src/` directory exists and contains Java files
- [ ] Verify `components/kitchensink/pom.xml` exists
- [ ] Verify `components/developer-hub/templates/jboss-template/skeleton/` is populated

**Validation**:
```bash
# Should show Java source files
ls -la components/kitchensink/src/main/java/org/jboss/as/quickstarts/kitchensink/

# Should show pom.xml
test -f components/kitchensink/pom.xml && echo "✓ pom.xml exists"

# Should show skeleton files
ls -la components/developer-hub/templates/jboss-template/skeleton/
```

### 2. Repository Configuration

- [ ] Forked this repository to your GitHub account
- [ ] Cloned your fork locally
- [ ] Updated all `CHANGEME` placeholders with your GitHub username
- [ ] Updated Quay.io registry organization
- [ ] Committed and pushed changes to your fork

**Validation**:
```bash
# Should return no results
grep -r "CHANGEME" --include="*.yaml" .

# Should show your username
grep "repoURL:" argocd/app-of-apps.yaml
```

### 3. External Accounts

- [ ] GitHub account with fork of this repository
- [ ] Quay.io account (free tier is fine)
- [ ] GitHub personal access token created with `repo` and `workflow` scopes
- [ ] Quay.io credentials (username/password or robot account)

**GitHub Token**: https://github.com/settings/tokens/new

**Required scopes**:
- ✅ `repo` - Full control of private repositories
- ✅ `workflow` - Update GitHub Action workflows

**Quay.io Account**: https://quay.io/signin/

### 4. OpenShift Cluster Access

- [ ] OpenShift 4.12+ cluster available
- [ ] `oc` CLI installed locally
- [ ] Logged in with cluster-admin privileges
- [ ] Cluster has at least 16GB RAM and 4 CPUs available

**Validation**:
```bash
# Check oc is installed
oc version --client

# Check you're logged in
oc whoami

# Check cluster version
oc get clusterversion

# Check you have admin permissions
oc auth can-i create namespace --all-namespaces
# Should return: yes

# Check available resources
oc adm top nodes
```

### 5. Required Tools Installed

- [ ] `git` installed
- [ ] `oc` CLI installed
- [ ] `bash` shell available

**Optional (for better experience)**:
- [ ] `tkn` CLI (Tekton CLI) - for viewing pipeline runs
- [ ] `argocd` CLI - for managing ArgoCD applications

**Validation**:
```bash
git --version
oc version --client
bash --version

# Optional
tkn version 2>/dev/null || echo "tkn not installed (optional)"
argocd version --client 2>/dev/null || echo "argocd not installed (optional)"
```

## ✅ Installation Checklist

### 1. Pre-Installation Verification

- [ ] Run pre-flight checks
  ```bash
  cd bootstrap
  ./install.sh
  # It will validate prerequisites before installing
  ```

### 2. Installation

- [ ] Run installer: `./install.sh`
- [ ] Monitor progress: `./install.sh --status`
- [ ] Wait for all applications to show "Synced" and "Healthy" (~10-15 minutes)

### 3. Post-Installation Configuration

- [ ] Get access URLs: `./install.sh --urls`
- [ ] Configure Quay.io credentials:
  ```bash
  oc create secret docker-registry quay-credentials \
    --docker-server=quay.io \
    --docker-username=YOUR_USERNAME \
    --docker-password=YOUR_PASSWORD \
    -n kitchensink-dev
  
  oc secrets link pipeline quay-credentials -n kitchensink-dev
  ```

- [ ] Configure GitHub token for Developer Hub:
  ```bash
  oc create secret generic github-credentials \
    --from-literal=GITHUB_TOKEN=ghp_your_token \
    -n rhdh
  
  oc rollout restart deployment backstage -n rhdh
  ```

### 4. Verification Tests

- [ ] ArgoCD accessible and showing all apps as "Healthy"
- [ ] Developer Hub accessible and catalog loads
- [ ] DevSpaces accessible and workspace can be created
- [ ] Kitchensink application accessible and responds

**Quick verification**:
```bash
# All should return 200 OK
curl -I https://$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')
curl -I https://$(oc get route backstage -n rhdh -o jsonpath='{.spec.host}')
curl -I https://$(oc get route devspaces -n openshift-devspaces -o jsonpath='{.spec.host}')
curl -I http://$(oc get route kitchensink -n kitchensink-dev -o jsonpath='{.spec.host}')
```

## ✅ Demo Preparation Checklist

### 1. Pre-Demo Setup (15 minutes before)

- [ ] Run status check: `./bootstrap/install.sh --status`
- [ ] Get all URLs: `./bootstrap/install.sh --urls`
- [ ] Open DevSpaces workspace (let it start before demo)
- [ ] Test hot-reload in DevSpaces:
  - Start JBoss: `mvn wildfly:run -Dwildfly.dev`
  - Make a change
  - Verify reload works
  - Stop JBoss (`Ctrl+C`) - will restart live during demo

### 2. Browser Tabs Setup

- [ ] Demo script open (docs/DEMO-SCRIPT.md)
- [ ] DevSpaces workspace (already started)
- [ ] Kitchensink app URL (ready to navigate)
- [ ] Developer Hub (logged in)
- [ ] ArgoCD (logged in)
- [ ] GitHub repository

### 3. Test the Demo Flow

- [ ] Practice hot-reload demo (5 min)
- [ ] Practice Developer Hub template walkthrough (3 min)
- [ ] Review pipeline logs/history (2 min)

## ✅ Troubleshooting Checklist

If something goes wrong, check these in order:

### 1. Installation Issues

- [ ] Check all operators are "Succeeded": `oc get csv -A | grep -E "gitops|pipelines|devspaces|backstage"`
- [ ] Check ArgoCD apps: `oc get applications -n openshift-gitops`
- [ ] Check pod status: `oc get pods --all-namespaces | grep -v Running | grep -v Completed`
- [ ] Check events: `oc get events -A --sort-by='.lastTimestamp' | tail -20`

### 2. Pipeline Issues

- [ ] Registry credentials exist: `oc get secret quay-credentials -n kitchensink-dev`
- [ ] Secret linked to SA: `oc describe sa pipeline -n kitchensink-dev | grep Secrets`
- [ ] Pipeline exists: `oc get pipeline -n kitchensink-dev`
- [ ] Check latest run: `tkn pipelinerun describe -n kitchensink-dev $(tkn pipelinerun list -n kitchensink-dev -o name | head -1)`

### 3. DevSpaces Issues

- [ ] CheCluster ready: `oc get checluster -n openshift-devspaces`
- [ ] DevSpaces pods running: `oc get pods -n openshift-devspaces`
- [ ] User workspace exists: `oc get pods -n YOUR_USERNAME-devspaces`

### 4. Developer Hub Issues

- [ ] Backstage pod running: `oc get pods -n rhdh`
- [ ] GitHub token configured: `oc get secret github-credentials -n rhdh`
- [ ] Check logs: `oc logs -n rhdh deployment/backstage --tail=50`

## ✅ Cleanup Checklist

When you're done with the demo:

- [ ] Uninstall demo: `./bootstrap/install.sh --uninstall`
- [ ] Verify namespaces deleted:
  ```bash
  oc get namespace | grep -E "kitchensink|devspaces|rhdh"
  # Should return no results
  ```
- [ ] Optional: Remove operators if not used elsewhere
- [ ] Optional: Delete Quay.io images
- [ ] Optional: Delete forked GitHub repository

## Quick Reference

### Get Everything

```bash
# Status of all components
./bootstrap/install.sh --status

# All access URLs
./bootstrap/install.sh --urls
```

### View Logs

```bash
# ArgoCD
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-server --tail=50

# Developer Hub
oc logs -n rhdh deployment/backstage --tail=50

# DevSpaces
oc logs -n openshift-devspaces -l app=che --tail=50

# Kitchensink
oc logs -n kitchensink-dev deployment/kitchensink --tail=50

# Latest Pipeline Run
tkn pipelinerun logs -f -n kitchensink-dev --last
```

### Emergency Reset

```bash
# Restart ArgoCD
oc rollout restart deployment openshift-gitops-server -n openshift-gitops

# Restart Developer Hub
oc rollout restart deployment backstage -n rhdh

# Restart DevSpaces
oc rollout restart deployment che -n openshift-devspaces

# Restart Kitchensink
oc rollout restart deployment kitchensink -n kitchensink-dev
```

---

## Print This Checklist

```bash
# Generate a printable version
cat SETUP-CHECKLIST.md | grep "^\- \[ \]" > my-checklist.txt
```

Good luck with your setup and demo! 🎯
