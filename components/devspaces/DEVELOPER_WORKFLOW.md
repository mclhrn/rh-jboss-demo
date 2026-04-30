# DevSpaces Developer Workflow

Red Hat OpenShift Dev Spaces provides a cloud-based development environment with hot-reload capabilities for JBoss applications.

## Quick Start

### 1. Open Workspace

Click this link to open the kitchensink workspace in DevSpaces:

```
https://devspaces.apps.cluster-c6tf7.dynamic.redhatworkshops.io/#https://github.com/mclhrn/rh-jboss-demo?che-editor=che-incubator/che-code/latest&devfilePath=components/kitchensink/devfile.yaml
```

**Note:** Replace `devspaces.apps.cluster-c6tf7.dynamic.redhatworkshops.io` with your cluster's DevSpaces URL.

### 2. Initial Setup (First Time Only)

Once the workspace loads, run these commands in the terminal:

```bash
cd /projects/rh-jboss-demo/components/kitchensink

# Download WildFly (only needed once)
wget -q https://github.com/wildfly/wildfly/releases/download/27.0.1.Final/wildfly-27.0.1.Final.tar.gz
tar -xzf wildfly-27.0.1.Final.tar.gz
rm wildfly-27.0.1.Final.tar.gz

# Build the application
mvn clean package -DskipTests
```

### 3. Start the Application

```bash
# Deploy the WAR file
cp target/kitchensink.war wildfly-27.0.1.Final/standalone/deployments/ROOT.war

# Start WildFly on port 9090
./wildfly-27.0.1.Final/bin/standalone.sh -b 0.0.0.0 \
  -Djboss.http.port=9090 \
  -Djboss.https.port=9443 \
  -Djboss.management.http.port=10990
```

Wait for WildFly to start (look for `WFLYSRV0025: WildFly Full 27.0.1.Final started`).

### 4. Access the Application

1. In VS Code, expand **ENDPOINTS** in the left sidebar
2. Click on **wildfly-app (9090/http)** to open the application
3. You should see the Kitchensink registration form

### 5. Enable Hot-Reload (Inner-Loop Development)

**Open a second terminal** and run:

```bash
cd /projects/rh-jboss-demo/components/kitchensink

# Watch for changes and auto-redeploy
while true; do
  mvn package -DskipTests -q
  cp target/kitchensink.war wildfly-27.0.1.Final/standalone/deployments/ROOT.war
  echo "Deployed at $(date)"
  sleep 5
done
```

### 6. Make Code Changes

**Try it out:**

1. Open `src/main/webapp/index.xhtml`
2. Change line 18: `<h1>Welcome to JBoss!</h1>`
3. Update to: `<h1>Welcome to JBoss with DevSpaces! 🚀</h1>`
4. **Save the file** (Ctrl+S or Cmd+S)
5. Wait 5-10 seconds for the watch loop to rebuild and redeploy
6. **Refresh the browser** - see your changes instantly!

## Developer Experience Benefits

### ✅ No Local Setup Required
- No need to install JDK, Maven, or WildFly locally
- Everything runs in the cloud
- Consistent environment across team

### ✅ Fast Inner-Loop Development
- Code → Save → See changes in ~5-10 seconds
- No manual build/deploy steps
- WildFly automatically detects and redeploys changes

### ✅ Integrated Development Environment
- Full VS Code experience in the browser
- Syntax highlighting, IntelliSense, debugging
- Git integration built-in

### ✅ Resource Isolation
- Development environment doesn't consume local machine resources
- 4GB memory, 2 CPUs dedicated to development
- Persistent Maven cache for faster builds

## Architecture

```
┌─────────────────────────────────────────┐
│         DevSpaces Workspace             │
│  ┌───────────────────────────────────┐  │
│  │   Tools Container                 │  │
│  │   - Universal Dev Image           │  │
│  │   - Maven, JDK 11, Git           │  │
│  │   - WildFly 27.0.1.Final         │  │
│  │                                   │  │
│  │   Port 9090 → Kitchensink App    │  │
│  │   Port 5005 → Debug Port         │  │
│  └───────────────────────────────────┘  │
│                                         │
│  Persistent Volume: Maven Cache (3Gi)  │
└─────────────────────────────────────────┘
```

## Troubleshooting

### Workspace Won't Start
- Check DevSpaces operator is running: `oc get pods -n openshift-devspaces`
- Verify cluster has sufficient resources (4Gi memory minimum)

### Port 9090 Not Accessible
- Check ENDPOINTS section shows `wildfly-app (9090/http)` as Public
- If port shows as Internal, try deleting and recreating the workspace
- Verify WildFly started successfully in the terminal logs

### Hot-Reload Not Working
- Ensure the watch loop is running in a separate terminal
- Check Maven build completes without errors: `mvn package -DskipTests`
- Verify the WAR is being copied: `ls -lh wildfly-27.0.1.Final/standalone/deployments/ROOT.war`
- Watch WildFly logs for redeployment messages

### Application Errors
- Check WildFly logs: `tail -f wildfly-27.0.1.Final/standalone/log/server.log`
- Verify database is running: H2 should be embedded and start automatically
- Check for port conflicts: `netstat -tuln | grep 9090`

## Next Steps

- **CI/CD Pipeline**: Push changes to Git to trigger Tekton pipeline → builds container → deploys to production
- **Local Development**: Set up VS Code locally with JBoss Tools for offline development
- **Debugging**: Use port 5005 for remote debugging in DevSpaces
