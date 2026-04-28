# Demo Script: JBoss Modernization

Complete demo script for showcasing modern JBoss development, inner-loop workflows, and GitOps CI/CD to WebSphere teams.

## Demo Overview

**Target Audience**: Development teams migrating from WebSphere to JBoss
**Duration**: 30 minutes
**Focus**: Inner-loop developer experience, then CI/CD automation

## Pre-Demo Setup (15 minutes before)

### 1. Verify Installation

```bash
# Check all components are healthy
cd bootstrap
./install.sh --status

# All should show "Synced" and "Healthy"
```

### 2. Get Access URLs

```bash
./install.sh --urls

# Save these URLs - you'll need them:
# - ArgoCD Console
# - Developer Hub
# - DevSpaces
# - Kitchensink App
```

### 3. Prepare DevSpaces Workspace

```bash
# Get DevSpaces URL
DEVSPACES_URL=$(oc get route devspaces -n openshift-devspaces -o jsonpath='{.spec.host}')

# Open workspace (do this BEFORE the demo)
# Format: https://DEVSPACES_URL/#GIT_REPO_URL
echo "Open: https://${DEVSPACES_URL}/#https://github.com/YOUR_USERNAME/rh-jboss-demo"
```

**In the workspace**:
1. Wait for workspace to fully start (~60 seconds)
2. Open terminal
3. Navigate to kitchensink: `cd components/kitchensink`
4. DO NOT start the server yet - save this for the live demo
5. Keep the workspace tab open

### 4. Prepare Browser Tabs

Open these tabs in order:
1. This demo script (for reference)
2. DevSpaces workspace (already started)
3. Kitchensink running app (get URL, don't navigate yet)
4. Developer Hub (logged in)
5. ArgoCD (logged in)
6. GitHub repo (your fork)

### 5. Test the Demo Flow

Do a quick dry run:
1. Start JBoss in DevSpaces: `mvn wildfly:run -Dwildfly.dev`
2. Wait for server to start
3. Make a small change to `index.xhtml`
4. Verify hot-reload works
5. Stop the server (`Ctrl+C`)

**IMPORTANT**: Leave the server stopped for the actual demo. You'll start it live.

---

## Demo Script

### Part 1: The Problem (3 minutes)

**Opening**:
> "Thank you for your time today. I understand you're in the process of migrating from WebSphere to JBoss, and you've already successfully moved one application. Today, I want to show you how you can dramatically improve your development workflow while completing this migration."

**Set the Context**:
> "Based on our conversations, I understand your development teams are currently experiencing some challenges:"
> - "Code changes in Eclipse with WebSphere can take 5 minutes or more to see in the running application"
> - "Your current SDLC is non-containerized and heavily manual"
> - "Onboarding new developers is time-consuming due to tool sprawl and inconsistent setups"

**Frame the Solution**:
> "What I'm going to show you today addresses all of these pain points. We'll focus on two main areas:"
> 1. "**Inner-loop development**: Getting your developers from 5 minutes to 5 seconds per code change"
> 2. "**Automation and GitOps**: Showing how modern CI/CD eliminates manual deployment steps"

**Transition**:
> "Let's start with the problem that impacts your developers every single day: the inner-loop development cycle."

---

### Part 2: Inner-Loop Development (10 minutes)

#### 2.1 Show the Current State (2 minutes)

**Explain the Old Workflow** (verbal only, don't demo):
> "Currently, when a developer wants to see a code change in your WebSphere environment, here's what happens:"

Draw on whiteboard or show diagram:
```
Edit in Eclipse → Save → Eclipse republish (1-2 min) 
  → WebSphere detects (1 min) → Undeploy old (1 min) 
  → Deploy new (1-2 min) → Restart app (1 min)
  = 5-7 minutes total
```

> "If a developer makes 50 changes in a day—which is typical—that's 250 minutes, or over 4 hours, just waiting."

**Introduce the Modern Approach**:
> "The modern approach uses **hot-reload technology** and **containerized development environments**. Let me show you."

#### 2.2 DevSpaces Hot-Reload Demo (5 minutes)

**Switch to DevSpaces tab**:

> "This is OpenShift DevSpaces. It's a browser-based development environment with JBoss EAP already configured and ready to go. No local installation required."

**Show the workspace**:
- Point out the VS Code interface in the browser
- Show the file tree: `components/kitchensink/src/`
- Show the terminal pane

**Start the JBoss Server**:

```bash
# In DevSpaces terminal
cd components/kitchensink
mvn wildfly:run -Dwildfly.dev
```

> "I'm starting JBoss EAP in **development mode** with the `-Dwildfly.dev` flag. This enables hot-reload, meaning it will watch for file changes and automatically update the running application."

**Wait for server to start** (~30 seconds):
- Point out the startup logs
- Highlight "Started" message

> "Server is up. Now let's open the running application."

**Open the kitchensink app**:
- Click the endpoint notification, OR
- Switch to the kitchensink app tab you prepared

> "This is a simple member registration application. It's a classic JBoss quickstart that demonstrates all the core Java EE technologies."

**Interact with the app**:
- Register a test member:
  - Name: "John Doe"
  - Email: "john@example.com"
  - Phone: "5555551234"
- Show the member appears in the list

**Make a code change**:

> "Now, let's say product wants to change the welcome message. Watch how fast this is."

- Switch back to DevSpaces
- Open `src/main/webapp/index.xhtml`
- Find line ~32: `<h1>Welcome to JBoss!</h1>`
- Change to: `<h1>Welcome to Modern JBoss Development!</h1>`
- **Save the file** (`Cmd+S` or `Ctrl+S`)

**Watch the terminal**:
```
[INFO] Reloading webapp...
[INFO] Reloaded in 2.3 seconds
```

> "Look at the terminal. Maven detected the change, recompiled the file, and reloaded the application. That took 2 seconds."

**Refresh the app**:
- Switch to the kitchensink app tab
- Refresh the browser
- Point out the new heading

**The Impact**:
> "From making the change to seeing it live: **3 seconds**."
> 
> "Compare this to your current 5-minute cycle. If we multiply that across 50 changes per day, per developer:"
> 
> - Old way: 50 × 5 min = 250 minutes (**4+ hours waiting**)
> - New way: 50 × 5 sec = 250 seconds (**4 minutes waiting**)
> 
> "That's a **98% reduction in wait time**, which translates to developers spending their day writing code instead of watching progress bars."

#### 2.3 Show Local Development Option (3 minutes)

> "Now, some of your developers might prefer working in their local IDE rather than a browser. We support that too with the same fast experience."

**Briefly show VS Code + odo** (if time permits, otherwise explain verbally):

> "Using a tool called `odo`, developers can:"
> - Work in their local VS Code or IntelliJ
> - Have their local files automatically sync to a container in OpenShift
> - Get the same hot-reload experience
> 
> "The app actually runs in the cluster—not on their laptop—but they develop with their familiar local IDE."

**Benefits summary**:
> "With both options, your developers get:"
> 1. "**Consistent environments**: Everyone has the exact same JBoss version, dependencies, configuration"
> 2. "**Fast inner loop**: Changes visible in seconds, not minutes"
> 3. "**No local setup**: DevSpaces works from any device, even an iPad"
> 4. "**Develop against real cluster**: Catches environment issues early"

**Transition**:
> "So that solves the inner-loop problem. Now let's talk about what happens when developers are ready to deploy their changes..."

---

### Part 3: Developer Onboarding (5 minutes)

> "Before we get to CI/CD, let me briefly show you how we address the onboarding and tool sprawl challenge."

**Switch to Developer Hub tab**:

> "This is Red Hat Developer Hub, based on Backstage. It's a unified developer portal."

**Show the Service Catalog**:
- Click "Catalog" in the left sidebar
- Point out the kitchensink service
- Click on it to show details

> "This is your organization's service catalog. Every application, API, and service in one place. New developers can discover what exists and understand how it all fits together."

**Show Software Templates**:
- Click "Create" in the left sidebar
- Point out available templates
- Select "JBoss EAP Application"

> "Here's the really powerful part: self-service application creation with best practices baked in."

**Walk through template fields** (don't actually create unless requested):
- Application name
- Description
- Git repository
- Quay.io registry
- JBoss version
- Database choice

> "When a developer fills this out and clicks 'Create', Developer Hub:"
> 1. "Creates a new Git repository"
> 2. "Generates complete application code based on the kitchensink pattern"
> 3. "Includes Kubernetes manifests, CI/CD pipeline, devfile for DevSpaces"
> 4. "Registers it in the catalog"
> 5. "All in about 30 seconds."

**The Impact**:
> "Instead of spending 2-3 days setting up a new project and figuring out how to integrate all the tools, developers go from zero to productive in 30 seconds."

**Transition**:
> "Now, let's look at what happens after development—the path to production."

---

### Part 4: CI/CD and GitOps (10 minutes)

#### 4.1 Explain the Pipeline (2 minutes)

> "In your current environment, deployments are manual and error-prone. Let me show you the automated approach."

**Show the architecture** (use diagram from README or draw on whiteboard):

```
Developer → Git Push → Tekton Pipeline 
  → Build & Scan → Push to Quay 
  → Update Manifest → ArgoCD Syncs → Deployed
```

> "Here's how it works:"
> 1. "Developer pushes code to Git"
> 2. "Tekton pipeline automatically triggers"
> 3. "Pipeline builds the app, creates container image, scans for vulnerabilities"
> 4. "Pushes image to Quay.io registry"
> 5. "Updates the Kubernetes manifest with the new image tag"
> 6. "ArgoCD detects the change and deploys to the cluster"
> 7. "All automatic. Zero manual steps."

#### 4.2 Show ArgoCD (3 minutes)

**Switch to ArgoCD tab**:

> "This is ArgoCD, our GitOps deployment engine. It continuously monitors Git and ensures the cluster matches what's defined in Git."

**Show the Application List**:
- Point out all the applications: kitchensink, developer-hub, devspaces, etc.
- Click on "kitchensink"

**Show the Application Details**:
- Point out "Synced" and "Healthy" status
- Click on the visual topology view
- Show the deployment, service, route resources

> "This is the current state of our application. ArgoCD pulled all of this from Git and deployed it. If someone manually changes something on the cluster, ArgoCD will automatically revert it back to what's in Git."

**Explain GitOps Benefits**:
> "This GitOps approach gives you:"
> 1. "**Audit trail**: Every change is a Git commit with author and timestamp"
> 2. "**Rollback**: Revert to any previous version by reverting a Git commit"
> 3. "**Disaster recovery**: Cluster dies? Spin up a new one, point ArgoCD at Git, everything redeploys automatically"
> 4. "**Consistency**: Dev, staging, prod all deployed the same way from the same source"

#### 4.3 Trigger a Pipeline (if time permits) (5 minutes)

**Option A: Show existing PipelineRun**

```bash
# In a terminal (not visible to audience)
oc get pipelinerun -n kitchensink-dev

# Show the most recent run
tkn pipelinerun describe <latest-run> -n kitchensink-dev
```

> "Here's a recent pipeline run. You can see it:"
> - Cloned the code
> - Built with Maven
> - Created a container image
> - Pushed to Quay
> - All completed in about 6 minutes

**Option B: Trigger a new pipeline (if time allows)**

Make a trivial code change and push:

```bash
# In a terminal (not visible to audience)
cd rh-jboss-demo
echo "# Trigger pipeline" >> components/kitchensink/README.md
git add .
git commit -m "Trigger demo pipeline"
git push
```

Then show:
```bash
# Watch for new PipelineRun
tkn pipelinerun logs -f -n kitchensink-dev --last
```

> "I just pushed a change to Git. Watch as the pipeline automatically starts..."

(Show the pipeline running in the OpenShift Console or with `tkn` CLI)

> "In a real scenario, this would take 6-8 minutes to complete. Then ArgoCD would automatically pick up the new image and deploy it."

**Highlight the simplicity**:
> "The developer didn't configure anything. They just pushed code. Everything else is automatic."

---

### Part 5: Wrap-Up and Q&A (2 minutes)

**Summarize What They Saw**:

> "To recap, today you saw:"
> 
> 1. "**Inner-loop development**: 5-second hot-reload vs. your current 5-minute cycle—a 98% improvement"
> 2. "**Flexible development options**: DevSpaces in the browser OR local VS Code with the same fast experience"
> 3. "**Developer onboarding**: Self-service application generation reducing setup from days to seconds"
> 4. "**GitOps CI/CD**: Fully automated pipeline from code commit to production deployment"

**The Business Case**:

> "In concrete terms, for a team of 10 developers:"
> - "Inner-loop improvements save ~40 developer-hours per day"
> - "Automated pipelines eliminate ~10 hours per week of manual deployment work"
> - "Faster onboarding means new developers contribute in days instead of weeks"
> - "Containerization means 'works on my machine' problems disappear"

**Next Steps**:

> "I'd recommend:"
> 1. "We install this demo environment on your OpenShift cluster so your team can try it hands-on"
> 2. "We run a workshop where developers can experience the hot-reload firsthand"
> 3. "We work together to migrate one of your applications to this workflow as a proof of concept"

**Open for Questions**:
> "What questions do you have? What would you like to see in more detail?"

---

## Common Questions and Answers

### Q: "Does this work with our existing Eclipse-based workflow?"

**A**: 
> "DevSpaces is browser-based, but we also support local IDEs. Developers can use VS Code, IntelliJ, or even Eclipse with a plugin called `odo` that provides the same hot-reload experience. The app runs in OpenShift, but files are automatically synced from their local IDE."

### Q: "What if we need to use a different database than H2?"

**A**: 
> "Great question. The kitchensink demo uses H2 for simplicity, but in production you'd use PostgreSQL, MySQL, or Oracle. The Developer Hub templates can generate applications configured for any of these databases. The hot-reload works the same way regardless of which database you're using."

### Q: "How do we handle secrets like database passwords?"

**A**: 
> "Secrets are stored in Kubernetes Secrets and injected as environment variables at runtime. They're never committed to Git. The pipeline has access to registry credentials via Kubernetes service accounts. For more sensitive secrets, you can integrate with HashiCorp Vault or Red Hat Advanced Cluster Security."

### Q: "What's the learning curve for our developers?"

**A**: 
> "If they know JBoss and Java EE, there's minimal learning curve. The development experience is familiar—it's still Maven, still Java, still JBoss EAP. The main differences are:"
> 1. "Hot-reload is faster (they'll love this)"
> 2. "DevSpaces is in the browser (but VS Code users can stick with local)"
> 3. "Git push triggers automation (they'll adapt quickly)"
> 
> "We typically see developers fully productive within a day or two of hands-on experience."

### Q: "Can we do blue-green or canary deployments?"

**A**: 
> "Absolutely. ArgoCD integrates with Argo Rollouts for advanced deployment strategies like blue-green, canary, and progressive delivery. We can set that up so new versions gradually roll out with automatic rollback if metrics degrade."

### Q: "What about compliance and audit requirements?"

**A**: 
> "GitOps actually makes compliance easier. Every change is a Git commit with full audit trail:"
> - "Who made the change"
> - "When it was made"
> - "What specifically changed (Git diff)"
> - "Code review approvals (Pull Request history)"
> 
> "Plus, ArgoCD enforces that production exactly matches what's in Git. No manual changes, no drift."

### Q: "How does this work with multiple environments (dev, test, prod)?"

**A**: 
> "We typically use Git branches or directories for environment separation:"
> - "Option 1: Separate branches (main = prod, staging = test, etc.)"
> - "Option 2: Kustomize overlays (base + environment-specific patches)"
> - "ArgoCD can deploy different branches/directories to different clusters or namespaces"
> 
> "The pipeline can be configured to auto-deploy to dev, but require approval for prod."

---

## Troubleshooting During Demo

### DevSpaces workspace won't start
- **Fallback**: Use a pre-recorded video of the hot-reload demo
- **Prevention**: Start workspace 5 minutes before demo

### Hot-reload doesn't work
- **Check**: Is `mvn wildfly:run -Dwildfly.dev` running (not just `mvn wildfly:run`)?
- **Fallback**: Restart Maven with correct flags, or show logs proving it reloaded

### Pipeline takes too long
- **Strategy**: Don't trigger during demo; show completed PipelineRun instead
- **Backup**: Have a pre-recorded video of pipeline execution

### ArgoCD not accessible
- **Fallback**: Use screenshots or recorded walkthrough
- **Prevention**: Verify access before demo starts

---

## Post-Demo Follow-Up

### Materials to Send

1. Link to this GitHub repository
2. Recording of the demo (if recorded)
3. One-page summary of ROI/benefits
4. Proposed workshop agenda

### Proposed Workshop Outline (4 hours)

**Hour 1**: Hands-on inner-loop development
- Each developer gets their own DevSpaces workspace
- Make changes to kitchensink
- Experience hot-reload firsthand

**Hour 2**: Create a new application
- Use Developer Hub templates
- Generate a new JBoss application
- Customize it for their needs

**Hour 3**: CI/CD deep dive
- Review Tekton pipeline YAML
- Customize pipeline for their requirements
- Add security scanning, testing

**Hour 4**: Production readiness
- Multi-environment setup
- Secrets management
- Monitoring and logging integration

---

## Notes for Presenter

- **Pace yourself**: Pause after each section for questions
- **Make it interactive**: Ask if they've experienced similar pain points
- **Focus on value**: Always relate features back to time saved or problems solved
- **Be authentic**: If something breaks, explain it honestly and have fallbacks ready
- **Customize**: Adjust depth based on audience technical level (developers vs. managers)
- **Follow their lead**: If they're excited about inner-loop, spend more time there. If they care more about CI/CD, adjust accordingly.

Good luck with the demo!
