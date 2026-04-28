# Red Hat JBoss Modernization Demo

A comprehensive demonstration showcasing modern JBoss EAP development with Red Hat OpenShift, focusing on inner-loop developer experience and GitOps-based CI/CD workflows.

## Overview

This demo addresses common pain points for WebSphere development teams transitioning to JBoss EAP, particularly:

- **Slow inner-loop development**: 5+ minute waits for code changes to reflect
- **Non-containerized workflows**: Manual deployment processes
- **Tool sprawl**: Inconsistent developer onboarding and tooling
- **Lack of modern CI/CD**: Manual, error-prone release processes

## What Gets Installed

This repository provides a **one-click installation** that deploys:

### Core Platform
- **OpenShift GitOps (ArgoCD)**: GitOps-based application deployment
- **OpenShift Pipelines (Tekton)**: Cloud-native CI/CD pipelines
- **OpenShift DevSpaces**: Browser-based IDE with hot-reload
- **Red Hat Developer Hub**: Developer portal with software templates

### Demo Application
- **Kitchensink JBoss Application**: Classic JBoss EAP starter app
  - Containerized deployment
  - DevSpaces workspace configuration
  - VS Code + odo local development setup
  - Tekton pipeline for builds
  - GitOps deployment manifests

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     OpenShift Cluster                       │
│                                                             │
│  ┌──────────────┐         ┌──────────────┐                  │
│  │   Developer  │         │  DevSpaces   │                  │
│  │     Hub      │────────▶│  Workspace   │                  │
│  │              │         │ (Hot Reload) │                  │
│  └──────────────┘         └──────────────┘                  │
│         │                                                   │
│         │ Software Templates                                │
│         ▼                                                   │
│  ┌──────────────────────────────────────┐                   │
│  │         Git Repository               │                   │
│  │    (Kitchensink Source Code)         │                   │
│  └──────────────────────────────────────┘                   │
│         │                                                   │
│         │ Git Push                                          │
│         ▼                                                   │
│  ┌──────────────┐         ┌──────────────┐                  │
│  │   Tekton     │────────▶│  Quay.io     │                  │
│  │   Pipeline   │  Push   │  Registry    │                  │
│  │              │  Image  │  (Scanning)  │                  │
│  └──────────────┘         └──────────────┘                  │
│         │                        │                          │
│         │ Update Manifest        │                          │
│         ▼                        │                          │
│  ┌──────────────┐                │                          │
│  │   ArgoCD     │◀───────────────┘                          │
│  │   (GitOps)   │  Sync Image                               │
│  └──────────────┘                                           │
│         │                                                   │
│         │ Deploy                                            │
│         ▼                                                   │
│  ┌──────────────┐                                           │
│  │ Kitchensink  │                                           │
│  │  Running App │                                           │
│  └──────────────┘                                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘

Local Development Option:
┌──────────────┐
│  VS Code +   │──▶ (odo) ──▶ OpenShift
│     odo      │
└──────────────┘
```

## Quick Start

### Prerequisites

- OpenShift 4.12+ cluster with cluster-admin access
- `oc` CLI installed and logged in
- Git repository hosting (GitHub, GitLab, etc.) for forking this repo

### Installation

1. **Fork this repository** to your Git provider (required for GitOps to work)

2. **Update the repository URL** in `argocd/app-of-apps.yaml`:
   ```bash
   # Replace YOUR_GIT_REPO_URL with your forked repository
   sed -i 's|https://github.com/CHANGEME/rh-jboss-demo|YOUR_GIT_REPO_URL|g' argocd/app-of-apps.yaml
   ```

3. **Run the bootstrap installer**:
   ```bash
   cd bootstrap
   ./install.sh
   ```

4. **Wait for installation** (5-10 minutes):
   - The script will install OpenShift GitOps operator
   - ArgoCD will then install all other components
   - Monitor progress: `./install.sh --status`

5. **Access the demo**:
   ```bash
   # Get all URLs
   ./install.sh --urls
   ```

## Demo Flow

### Part 1: Inner-Loop Development (10 minutes)

**Problem Statement**: "Your current Eclipse + WebSphere setup takes 5 minutes per code change. Let's see the modern approach."

1. **DevSpaces Demo** (Browser-based)
   - Open DevSpaces workspace URL
   - Show pre-configured JBoss environment
   - Make a UI change (e.g., edit `src/main/webapp/index.xhtml`)
   - Watch hot-reload in seconds
   - See: `docs/INNER-LOOP.md`

2. **VS Code + odo Demo** (Local IDE)
   - Clone the kitchensink repo
   - Show odo sync to cluster
   - Same hot-reload experience, familiar IDE
   - See: `docs/INNER-LOOP.md`

### Part 2: Developer Onboarding (5 minutes)

**Problem Statement**: "Tool sprawl makes onboarding new developers painful."

1. **Developer Hub Tour**
   - Show software templates catalog
   - Create new JBoss app from template
   - All tooling (pipeline, deployment, devfile) generated
   - See: `components/developer-hub/README.md`

### Part 3: CI/CD & GitOps (10 minutes)

**Problem Statement**: "Manual deployments are error-prone and slow."

1. **Commit & Pipeline**
   - Push a change to Git
   - Watch Tekton pipeline trigger
   - Build → Scan → Push to Quay
   - See: `components/pipelines/README.md`

2. **GitOps Deployment**
   - ArgoCD detects new image
   - Auto-sync to cluster
   - Rollback demo (revert Git commit)
   - See: `argocd/README.md`

## Repository Structure

```
rh-jboss-demo/
├── README.md                        # This file
├── bootstrap/
│   ├── README.md                    # Installation details
│   └── install.sh                   # One-click installer
├── argocd/
│   ├── README.md                    # GitOps explanation
│   ├── app-of-apps.yaml            # Parent ArgoCD application
│   └── applications/                # Child applications
│       ├── openshift-gitops.yaml
│       ├── openshift-pipelines.yaml
│       ├── openshift-devspaces.yaml
│       ├── developer-hub.yaml
│       └── kitchensink.yaml
├── components/
│   ├── developer-hub/
│   │   ├── README.md               # RHDH setup and templates
│   │   ├── operator/               # Operator subscription
│   │   ├── instance/               # RHDH instance config
│   │   └── templates/              # Software templates
│   │       └── jboss-template/
│   ├── devspaces/
│   │   ├── README.md               # DevSpaces configuration
│   │   └── workspace-config/       # CheCluster config
│   ├── pipelines/
│   │   ├── README.md               # Tekton pipeline details
│   │   └── kitchensink-pipeline.yaml
│   └── kitchensink/
│       ├── README.md               # Application details
│       ├── src/                    # JBoss source code
│       ├── devfile.yaml            # DevSpaces config
│       ├── Containerfile           # Container build
│       ├── k8s/                    # Kubernetes manifests
│       └── .vscode/                # VS Code + odo config
└── docs/
    ├── DEMO-SCRIPT.md              # Complete demo narrative
    └── INNER-LOOP.md               # Inner-loop setup guide
```

## Customization

### Using Your Own Application

Replace the kitchensink app with your own JBoss application:

1. Update `components/kitchensink/` with your source code
2. Modify `components/kitchensink/devfile.yaml` for your app's requirements
3. Adjust `components/pipelines/kitchensink-pipeline.yaml` build steps
4. Update `components/kitchensink/k8s/` manifests

### Adjusting Pipeline Behavior

See `components/pipelines/README.md` for customizing:
- Build steps
- Image scanning policies
- Registry configuration
- Trigger conditions

### Developer Hub Templates

Add your own software templates in `components/developer-hub/templates/`
- See existing `jboss-template/` as an example
- Templates use Backstage template format
- See `components/developer-hub/README.md`

## Troubleshooting

### Installation Issues

```bash
# Check ArgoCD installation
oc get csv -n openshift-gitops

# Check app-of-apps status
oc get application -n openshift-gitops

# View specific application sync status
oc describe application kitchensink -n openshift-gitops
```

### DevSpaces Not Starting

```bash
# Check CheCluster status
oc get checluster -n openshift-devspaces

# View workspace pods
oc get pods -n openshift-devspaces
```

### Pipeline Not Triggering

```bash
# Check pipeline resources
oc get pipeline,pipelinerun -n kitchensink-dev

# View Tekton operator
oc get csv -n openshift-pipelines
```

## Cleanup

To remove all demo components:

```bash
cd bootstrap
./install.sh --uninstall
```

This will:
- Delete the app-of-apps ArgoCD application (cascades to all children)
- Remove operators (optional, prompted)
- Clean up namespaces

## Contributing

This demo is designed to be customizable. Feel free to:
- Add more software templates
- Enhance the pipeline with additional steps
- Include monitoring/observability components
- Add multi-environment promotion workflows

## Resources

- [JBoss EAP Documentation](https://access.redhat.com/documentation/en-us/red_hat_jboss_enterprise_application_platform/)
- [OpenShift GitOps](https://docs.openshift.com/gitops/)
- [OpenShift Pipelines](https://docs.openshift.com/pipelines/)
- [OpenShift DevSpaces](https://docs.openshift.com/devspaces/)
- [Red Hat Developer Hub](https://developers.redhat.com/rhdh)
- [Kitchensink Quickstart](https://github.com/jboss-developer/jboss-eap-quickstarts)

## License

This demo is provided as-is for educational and demonstration purposes.
