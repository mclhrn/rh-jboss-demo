# Local VS Code Development Setup

This guide shows how to set up a local development environment with VS Code and WildFly for hot-reload development.

## Prerequisites

- **Java 11** - Download from [Adoptium](https://adoptium.net/) or use SDKMAN
- **Maven 3.6+** - [Installation guide](https://maven.apache.org/install.html)
- **VS Code** - [Download](https://code.visualstudio.com/)
- **Git** - For cloning the repository

## Step 1: Install VS Code Extensions

Install these extensions for the best JBoss/Jakarta EE development experience:

### Required Extensions

1. **Extension Pack for Java** (Microsoft)
   - Includes: Language Support, Debugger, Test Runner, Maven, Project Manager
   - Extension ID: `vscjava.vscode-java-pack`

2. **Community Server Connectors** (Red Hat)
   - Supports WildFly, JBoss EAP, Tomcat
   - Extension ID: `redhat.vscode-community-server-connector`

3. **XML** (Red Hat)
   - For editing pom.xml, web.xml, persistence.xml
   - Extension ID: `redhat.vscode-xml`

### Recommended Extensions

4. **Language Support for Jakarta EE** (Red Hat)
   - IntelliSense for Jakarta EE APIs
   - Extension ID: `redhat.vscode-jakarta`

5. **YAML** (Red Hat)
   - For Kubernetes/OpenShift manifests
   - Extension ID: `redhat.vscode-yaml`

### Install via Command Line

```bash
code --install-extension vscjava.vscode-java-pack
code --install-extension redhat.vscode-community-server-connector
code --install-extension redhat.vscode-xml
code --install-extension redhat.vscode-jakarta
code --install-extension redhat.vscode-yaml
```

## Step 2: Clone the Repository

```bash
cd ~/projects  # or your preferred workspace directory
git clone https://github.com/mclhrn/rh-jboss-demo.git
cd rh-jboss-demo
code .
```

## Step 3: Download and Setup WildFly Locally

```bash
cd components/kitchensink

# Download WildFly 27
wget https://github.com/wildfly/wildfly/releases/download/27.0.1.Final/wildfly-27.0.1.Final.tar.gz

# Extract
tar -xzf wildfly-27.0.1.Final.tar.gz

# Clean up
rm wildfly-27.0.1.Final.tar.gz

# Add to PATH (optional)
export WILDFLY_HOME=$(pwd)/wildfly-27.0.1.Final
```

## Step 4: Build the Application

```bash
cd components/kitchensink
mvn clean package -DskipTests
```

## Step 5: Configure VS Code Tasks

Create `.vscode/tasks.json` in the project root:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Build Kitchensink",
      "type": "shell",
      "command": "mvn",
      "args": ["clean", "package", "-DskipTests"],
      "options": {
        "cwd": "${workspaceFolder}/components/kitchensink"
      },
      "group": {
        "kind": "build",
        "isDefault": true
      },
      "problemMatcher": []
    },
    {
      "label": "Start WildFly",
      "type": "shell",
      "command": "./wildfly-27.0.1.Final/bin/standalone.sh",
      "args": ["-b", "0.0.0.0"],
      "options": {
        "cwd": "${workspaceFolder}/components/kitchensink"
      },
      "isBackground": true,
      "problemMatcher": {
        "pattern": {
          "regexp": "^(.*)$",
          "file": 1,
          "location": 2,
          "message": 3
        },
        "background": {
          "activeOnStart": true,
          "beginsPattern": ".*WFLYSRV0049.*starting.*",
          "endsPattern": ".*WFLYSRV0025.*started.*"
        }
      }
    },
    {
      "label": "Watch and Deploy",
      "type": "shell",
      "command": "bash",
      "args": [
        "-c",
        "while true; do mvn package -DskipTests -q && cp target/kitchensink.war wildfly-27.0.1.Final/standalone/deployments/ROOT.war && echo 'Deployed at '$(date); sleep 5; done"
      ],
      "options": {
        "cwd": "${workspaceFolder}/components/kitchensink"
      },
      "isBackground": true,
      "problemMatcher": []
    }
  ]
}
```

## Step 6: Configure Launch Configuration for Debugging

Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "java",
      "name": "Debug WildFly",
      "request": "attach",
      "hostName": "localhost",
      "port": 8787,
      "timeout": 30000
    }
  ]
}
```

## Development Workflows

### Workflow 1: Manual Build and Deploy

```bash
# Terminal 1: Start WildFly
cd components/kitchensink
./wildfly-27.0.1.Final/bin/standalone.sh

# Terminal 2: Build and deploy
cd components/kitchensink
mvn clean package -DskipTests
cp target/kitchensink.war wildfly-27.0.1.Final/standalone/deployments/ROOT.war
```

Access the app at: http://localhost:8080

### Workflow 2: Hot-Reload Development (Recommended)

```bash
# Terminal 1: Start WildFly
cd components/kitchensink
./wildfly-27.0.1.Final/bin/standalone.sh

# Terminal 2: Start watch mode
cd components/kitchensink
while true; do
  mvn package -DskipTests -q
  cp target/kitchensink.war wildfly-27.0.1.Final/standalone/deployments/ROOT.war
  echo "Deployed at $(date)"
  sleep 5
done
```

**Make code changes:**
1. Edit any `.java` or `.xhtml` file
2. Save the file
3. Wait ~5-10 seconds
4. Refresh browser - see changes!

### Workflow 3: Using VS Code Tasks

1. **Build**: Press `Cmd+Shift+B` (Mac) or `Ctrl+Shift+B` (Windows/Linux)
   - Runs Maven build

2. **Start WildFly**: Press `Cmd+Shift+P` → "Tasks: Run Task" → "Start WildFly"
   - Starts WildFly in background

3. **Enable Hot-Reload**: Press `Cmd+Shift+P` → "Tasks: Run Task" → "Watch and Deploy"
   - Watches for file changes and auto-deploys

### Workflow 4: Debugging

**Start WildFly in debug mode:**

```bash
cd components/kitchensink
./wildfly-27.0.1.Final/bin/standalone.sh --debug
```

WildFly will start with debug port 8787 open.

**In VS Code:**
1. Set breakpoints in your Java code
2. Press `F5` or go to Run → Start Debugging
3. Select "Debug WildFly"
4. Trigger the code path in the browser
5. VS Code will pause at breakpoints

## Using Community Server Connectors Extension

The **Community Server Connectors** extension provides a GUI for managing WildFly:

### Setup Server

1. Open the **Servers** view (Activity Bar → Servers icon)
2. Click **"+"** to add a server
3. Select **"Download Server"** → **"WildFly 27.x"**
4. Or select **"Local Server"** and point to your WildFly installation

### Deploy Application

1. Right-click the server → **"Start Server"**
2. Right-click the server → **"Add Deployment"**
3. Select `components/kitchensink/target/kitchensink.war`
4. The app will deploy automatically

### Benefits

- ✅ Start/stop/restart server from GUI
- ✅ View server logs in Output panel
- ✅ Deploy/undeploy with right-click
- ✅ Automatic redeploy on file changes (if configured)

## IntelliSense and Code Navigation

With the Java extensions installed, you get:

- **Auto-completion**: Ctrl+Space for Jakarta EE APIs
- **Go to Definition**: F12 on any class/method
- **Find References**: Shift+F12
- **Rename Symbol**: F2
- **Organize Imports**: Shift+Alt+O
- **Format Code**: Shift+Alt+F

## Comparing DevSpaces vs Local

| Feature | DevSpaces | Local VS Code |
|---------|-----------|---------------|
| **Setup Time** | Instant (cloud-based) | 15-30 min (one-time) |
| **Resource Usage** | None (runs in cluster) | Local CPU/Memory |
| **Offline Work** | ❌ Requires internet | ✅ Works offline |
| **Team Consistency** | ✅ Same environment | ⚠️ Depends on local setup |
| **Performance** | Network dependent | ✅ Local is faster |
| **Debugging** | Remote attach | ✅ Native debugging |
| **Extensions** | Limited | ✅ Full marketplace |

## Troubleshooting

### Port 8080 Already in Use

```bash
# Find what's using port 8080
lsof -i :8080

# Kill the process
kill -9 <PID>

# Or use a different port
./wildfly-27.0.1.Final/bin/standalone.sh -Djboss.socket.binding.port-offset=100
# Access at http://localhost:8180
```

### Maven Build Fails

```bash
# Clean Maven cache
rm -rf ~/.m2/repository

# Rebuild
mvn clean install -U
```

### Hot-Reload Not Working

- Ensure WildFly's deployment scanner is running (it is by default)
- Check WildFly logs for deployment errors
- Verify the WAR file timestamp updates: `ls -lh wildfly-27.0.1.Final/standalone/deployments/ROOT.war`

### Java Extension Issues

- Reload VS Code: Cmd+Shift+P → "Reload Window"
- Clean Java workspace: Cmd+Shift+P → "Java: Clean Java Language Server Workspace"
- Check Java path: Cmd+Shift+P → "Java: Configure Java Runtime"

## Next Steps

- **Connect to OpenShift**: Deploy directly from VS Code using `oc` CLI
- **Set up Tekton Pipeline**: Push to Git triggers automatic build and deploy
- **Add Tests**: Run integration tests with Arquillian
- **Database Integration**: Connect to PostgreSQL instead of H2
