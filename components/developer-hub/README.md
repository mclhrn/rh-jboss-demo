# Red Hat Developer Hub Component

This component deploys Red Hat Developer Hub (RHDH), based on Backstage, providing a unified developer portal with self-service application scaffolding.

## Overview

Red Hat Developer Hub solves the **tool sprawl and onboarding problem** by providing:

- **Unified developer portal**: Single pane of glass for all development tools
- **Self-service templates**: Generate new applications with best practices baked in
- **Service catalog**: Discover and understand all services in your organization
- **Documentation hub**: Centralized technical documentation
- **Reduced onboarding time**: New developers productive in hours, not weeks

## What Gets Deployed

### 1. Developer Hub Operator

```yaml
components/developer-hub/operator/subscription.yaml
```

**Purpose**: Installs the Red Hat Developer Hub operator

**Resources**:
- Subscription to `backstage-operator` from Red Hat catalog
- Installs into `openshift-operators` namespace (cluster-wide)
- Manages Backstage custom resources

**Installation Time**: 2-3 minutes

### 2. Backstage Instance

```yaml
components/developer-hub/instance/backstage.yaml
```

**Purpose**: Creates the actual Developer Hub instance

**Resources**:
- Backstage CR in `rhdh` namespace
- Frontend web application (React)
- Backend API server (Node.js)
- PostgreSQL database (optional, embedded by default)
- Route for external access

**Installation Time**: 3-5 minutes

**Key Configuration**:
```yaml
spec:
  application:
    appConfig:
      app:
        title: Red Hat Developer Hub - JBoss Demo
        baseUrl: https://backstage-rhdh.apps.example.com
    extraEnvs:
      - name: NODE_ENV
        value: production
    replicas: 1
  database:
    enableLocalDb: true  # Use embedded PostgreSQL
```

### 3. Software Templates

```yaml
components/developer-hub/templates/jboss-template/template.yaml
```

**Purpose**: Provides self-service application generation

**What it creates**:
- New JBoss EAP application (like kitchensink)
- Complete with:
  - Source code
  - Containerfile
  - Kubernetes manifests
  - Tekton pipeline
  - DevSpaces devfile
  - README and documentation

**Template Parameters**:
- Application name
- Git repository URL
- Quay.io registry organization
- JBoss EAP version
- Database choice (H2, PostgreSQL, MySQL)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              Developer Hub (Backstage)                       │
│                                                              │
│  ┌──────────────────────────────────────────────┐          │
│  │  Frontend (React SPA)                        │          │
│  │  - Software catalog                          │          │
│  │  - Template scaffolder                       │          │
│  │  - TechDocs                                  │          │
│  │  - Plugins (Tekton, ArgoCD, etc.)            │          │
│  └──────────────────────────────────────────────┘          │
│                       │                                      │
│                       │ API calls                           │
│                       ▼                                      │
│  ┌──────────────────────────────────────────────┐          │
│  │  Backend (Node.js)                           │          │
│  │  - Catalog ingestion                         │          │
│  │  - Template processing                       │          │
│  │  - Authentication/authorization              │          │
│  │  - Plugin backends                           │          │
│  └──────────────────────────────────────────────┘          │
│                       │                                      │
│                       │ Store/retrieve                      │
│                       ▼                                      │
│  ┌──────────────────────────────────────────────┐          │
│  │  PostgreSQL Database                         │          │
│  │  - Catalog entities                          │          │
│  │  - User data                                 │          │
│  │  - Template metadata                         │          │
│  └──────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────┘
                       │
                       │ Integrations
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  External Systems                                            │
│  ├─ Git (GitHub/GitLab) - Source code hosting              │
│  ├─ ArgoCD - Deployment status                             │
│  ├─ Tekton - Pipeline status                               │
│  ├─ Quay.io - Container images                             │
│  └─ OpenShift - Cluster resources                          │
└─────────────────────────────────────────────────────────────┘
```

## Software Template: JBoss Quickstart

### Template Definition

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: jboss-eap-quickstart
  title: JBoss EAP Application
  description: Create a new JBoss EAP application with CI/CD
  tags:
    - java
    - jboss
    - eap
    - recommended
spec:
  owner: platform-team
  type: service

  parameters:
    - title: Application Details
      required:
        - component_id
        - owner
      properties:
        component_id:
          title: Name
          type: string
          description: Unique name for this application
          pattern: '^[a-z0-9-]+$'
        description:
          title: Description
          type: string
          description: What does this application do?
        owner:
          title: Owner
          type: string
          description: Team or person owning this application
          ui:field: OwnerPicker
          ui:options:
            allowedKinds:
              - Group
              - User

    - title: Repository Configuration
      required:
        - repoUrl
      properties:
        repoUrl:
          title: Repository Location
          type: string
          ui:field: RepoUrlPicker
          ui:options:
            allowedHosts:
              - github.com
              - gitlab.com

    - title: Deployment Configuration
      required:
        - registry_org
      properties:
        registry_org:
          title: Quay.io Organization
          type: string
          description: Your Quay.io organization name
        eap_version:
          title: JBoss EAP Version
          type: string
          description: JBoss EAP version to use
          default: '7.4'
          enum:
            - '7.4'
            - '8.0'
        database:
          title: Database
          type: string
          description: Database to use
          default: h2
          enum:
            - h2
            - postgresql
            - mysql

  steps:
    - id: fetch-base
      name: Fetch Base Template
      action: fetch:template
      input:
        url: ./skeleton
        values:
          component_id: ${{ parameters.component_id }}
          description: ${{ parameters.description }}
          owner: ${{ parameters.owner }}
          registry_org: ${{ parameters.registry_org }}
          eap_version: ${{ parameters.eap_version }}
          database: ${{ parameters.database }}

    - id: publish
      name: Publish to Git
      action: publish:github
      input:
        allowedHosts: ['github.com']
        description: ${{ parameters.description }}
        repoUrl: ${{ parameters.repoUrl }}
        defaultBranch: main

    - id: register
      name: Register Component
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps.publish.output.repoContentsUrl }}
        catalogInfoPath: '/catalog-info.yaml'

  output:
    links:
      - title: Repository
        url: ${{ steps.publish.output.remoteUrl }}
      - title: View in Catalog
        icon: catalog
        entityRef: ${{ steps.register.output.entityRef }}
```

### What the Template Generates

When a developer uses this template, Developer Hub creates:

**1. Application Source Code**
- `src/` directory with JBoss EAP application
- Based on kitchensink quickstart
- Customized with user's chosen database

**2. Container Configuration**
- `Containerfile` for building the image
- Parameterized with JBoss EAP version

**3. Kubernetes Manifests**
- `k8s/deployment.yaml`
- `k8s/service.yaml`
- `k8s/route.yaml`
- Pre-filled with application name and image registry

**4. CI/CD Pipeline**
- `pipeline.yaml` for Tekton
- Configured to push to user's Quay.io org
- Auto-configured ArgoCD sync

**5. Development Environment**
- `devfile.yaml` for DevSpaces
- `.vscode/` settings for local development

**6. Documentation**
- `README.md` with getting started guide
- `catalog-info.yaml` for Backstage catalog

**7. Git Repository**
- Creates new repo in GitHub/GitLab
- Pushes all generated files
- Registers in Developer Hub catalog

## Using Developer Hub

### Accessing the Portal

```bash
# Get Developer Hub URL
oc get route backstage -n rhdh -o jsonpath='{.spec.host}'

# Open in browser
open https://$(oc get route backstage -n rhdh -o jsonpath='{.spec.host}')

# Login with OpenShift credentials
# Developer Hub uses OpenShift OAuth by default
```

### Creating a New Application

**1. Navigate to "Create"**
- Click "Create" in the left sidebar
- Browse available templates
- Select "JBoss EAP Application"

**2. Fill in Application Details**
- **Name**: `my-jboss-app` (lowercase, hyphens only)
- **Description**: What the app does
- **Owner**: Your team name

**3. Configure Repository**
- **Repository Location**: `github.com/YOUR_ORG/my-jboss-app`
- **Repository Type**: Public or Private

**4. Configure Deployment**
- **Quay.io Organization**: Your Quay.io org
- **JBoss EAP Version**: 7.4 (recommended)
- **Database**: H2 (for demo) or PostgreSQL (for production)

**5. Review and Create**
- Review all parameters
- Click "Create"
- Watch progress in real-time

**6. What Happens Next**
- Developer Hub creates Git repository
- Pushes generated code
- Registers in service catalog
- Provides links to:
  - Git repository
  - DevSpaces workspace
  - Pipeline dashboard
  - ArgoCD application

**Timeline**: 30-60 seconds from clicking "Create" to having a working application

### Viewing Services in Catalog

**1. Navigate to "Catalog"**
- Click "Catalog" in left sidebar
- See all registered services

**2. Filter and Search**
- Filter by:
  - Owner (team/person)
  - Technology (Java, JBoss, etc.)
  - Lifecycle (dev, staging, prod)
- Search by name or description

**3. View Service Details**
- Click on a service
- See:
  - Overview and documentation
  - Dependencies (APIs, databases)
  - Links to:
    - Source code
    - CI/CD pipelines
    - Running deployments
    - Monitoring dashboards

## Demo Flow: Developer Onboarding

### Setup (Before Demo)

```bash
# Ensure Developer Hub is accessible
DEVHUB_URL=$(oc get route backstage -n rhdh -o jsonpath='{.spec.host}')
curl -I https://${DEVHUB_URL}

# Prepare a Quay.io organization
# Prepare GitHub token for creating repos
```

### Demo Script (5 minutes)

**1. The Problem (1 minute)**

*"Your developers spend days getting a new project set up. They need to figure out:"*
- Which JBoss version to use?
- How to configure the pipeline?
- Where to put manifests?
- How to structure the repository?
- How to integrate with existing tools?

*"And each team does it differently, so there's no consistency. Let me show you the modern approach."*

**2. Show Developer Hub Catalog (1 minute)**

- Open Developer Hub
- Navigate to Catalog
- Show existing services (including kitchensink)
- Point out: "This is your organization's service catalog. Every service, API, and tool in one place."

**3. Create New Application (3 minutes)**

1. **Click "Create"**
   - Show available templates
   - "These are curated by your platform team with best practices baked in"

2. **Select "JBoss EAP Application"**
   - Fill in details:
     - Name: `customer-api`
     - Description: "Customer management API"
     - Owner: "your-team"
   - Repository: GitHub URL
   - Quay.io org: Your organization

3. **Click "Create"**
   - Watch real-time progress
   - "In 30 seconds, Developer Hub is:"
     - Creating a Git repository
     - Generating complete application code
     - Setting up CI/CD pipeline
     - Configuring DevSpaces workspace
     - Creating Kubernetes manifests

4. **Show Results**
   - Repository created
   - Click "View in Catalog"
   - Show the new service in catalog
   - "The developer can now:"
     - Open DevSpaces and start coding
     - Push code and trigger pipeline
     - Deploy to cluster
   - "Onboarding time: 30 seconds vs 3 days"

## Customization

### Adding Custom Templates

Create new templates for other types of applications:

**1. Create template directory**:
```bash
mkdir -p components/developer-hub/templates/my-template/skeleton
```

**2. Create template.yaml**:
```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: my-custom-template
  title: My Custom Application
spec:
  # ... template definition
```

**3. Create skeleton files**:
```
skeleton/
├── src/
├── Containerfile
├── k8s/
├── catalog-info.yaml.template
└── README.md.template
```

**4. Register template**:
```yaml
# In instance/backstage.yaml
spec:
  application:
    appConfig:
      catalog:
        locations:
          - type: url
            target: https://github.com/YOUR_ORG/rh-jboss-demo/blob/main/components/developer-hub/templates/my-template/template.yaml
```

### Integrating with External Systems

**GitHub Integration**:
```yaml
spec:
  application:
    appConfig:
      integrations:
        github:
          - host: github.com
            token: ${GITHUB_TOKEN}
```

**ArgoCD Integration**:
```yaml
spec:
  application:
    appConfig:
      argocd:
        baseUrl: https://argocd-server.openshift-gitops.svc
        username: admin
        password: ${ARGOCD_PASSWORD}
```

**Tekton Integration**:
```yaml
spec:
  application:
    appConfig:
      kubernetes:
        clusterLocatorMethods:
          - type: config
            clusters:
              - url: https://kubernetes.default.svc
                name: openshift-local
                authProvider: serviceAccount
        customResources:
          - apiVersion: tekton.dev/v1
            group: tekton.dev
            plural: pipelines
          - apiVersion: tekton.dev/v1
            group: tekton.dev
            plural: pipelineruns
```

### Customizing UI Theme

```yaml
spec:
  application:
    appConfig:
      app:
        title: My Company Developer Hub
        branding:
          theme:
            light:
              primaryColor: '#E00'
              navigationBackground: '#222'
            dark:
              primaryColor: '#F44'
              navigationBackground: '#111'
```

## Troubleshooting

### Developer Hub Not Loading

**Symptom**: Backstage route returns 503 or blank page

**Diagnosis**:
```bash
# Check pod status
oc get pods -n rhdh

# Check logs
oc logs -n rhdh -l app=backstage

# Check route
oc get route backstage -n rhdh
```

**Common Causes**:
- Database not ready (if using external PostgreSQL)
- Configuration errors in app-config
- Missing authentication configuration

### Template Fails to Create Repository

**Symptom**: "Failed to publish to GitHub"

**Diagnosis**:
- Check GitHub token has correct permissions:
  - `repo` (full control of private repositories)
  - `workflow` (update GitHub Action workflows)

**Solution**:
```bash
# Update GitHub token secret
oc create secret generic github-credentials \
  -n rhdh \
  --from-literal=GITHUB_TOKEN=ghp_your_token_here \
  --dry-run=client -o yaml | oc apply -f -

# Restart Developer Hub
oc rollout restart deployment backstage -n rhdh
```

### Service Not Appearing in Catalog

**Symptom**: Created service doesn't show up in catalog

**Diagnosis**:
```bash
# Check catalog processor logs
oc logs -n rhdh -l app=backstage | grep catalog

# Verify catalog-info.yaml is valid
curl https://github.com/YOUR_ORG/my-app/blob/main/catalog-info.yaml
```

**Solution**:
- Ensure `catalog-info.yaml` is in repository root
- Validate YAML syntax
- Check entity `kind` is supported (Component, API, etc.)
- Manually re-trigger catalog refresh in UI

## Validation

After deployment, verify Developer Hub is working:

```bash
# Check operator
oc get csv -n openshift-operators | grep backstage

# Check Backstage instance
oc get backstage -n rhdh

# Check pods are running
oc get pods -n rhdh

# Get URL
DEVHUB_URL=$(oc get route backstage -n rhdh -o jsonpath='{.spec.host}')
echo "Developer Hub: https://${DEVHUB_URL}"

# Test accessibility
curl -I https://${DEVHUB_URL}

# Test catalog API
curl https://${DEVHUB_URL}/api/catalog/entities
```

## Resources

- [Red Hat Developer Hub Documentation](https://developers.redhat.com/rhdh)
- [Backstage Official Documentation](https://backstage.io/docs/)
- [Software Templates](https://backstage.io/docs/features/software-templates/)
- [Backstage Plugins](https://backstage.io/plugins)
- [Template Examples](https://github.com/backstage/software-templates)
