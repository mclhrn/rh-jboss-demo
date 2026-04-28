# Inner-Loop Development Guide

Hands-on guide for experiencing the fast inner-loop development workflow with JBoss EAP, showing both DevSpaces (browser-based) and VS Code + odo (local IDE) approaches.

## What is Inner-Loop Development?

The **inner loop** is the iterative cycle developers go through while coding:

```
Edit code → Build → Test → See result → Edit again
```

### The Problem: Traditional WebSphere Workflow

```
Edit in Eclipse → Save → Eclipse republish (1-2 min) 
  → WebSphere detects change (1 min) 
  → Undeploy old version (1 min) 
  → Deploy new version (1-2 min) 
  → Restart application (1 min)
  
Total: 5-7 minutes per change
```

**Impact**: 
- Developer makes ~50 changes per day
- 50 × 5 minutes = 250 minutes (4+ hours) waiting per day
- Productivity loss: ~50% of the day spent waiting

### The Solution: Modern JBoss with Hot-Reload

```
Edit in DevSpaces/VS Code → Save → Maven detects (instant)
  → Recompile changed files (1-2 sec)
  → Hot-swap classes (1 sec)
  → Application updated (instant)
  
Total: 2-5 seconds per change
```

**Impact**:
- Same 50 changes per day
- 50 × 5 seconds = 250 seconds (4 minutes) waiting per day
- Productivity gain: ~98% reduction in wait time

---

## Option 1: DevSpaces (Browser-Based IDE)

### Prerequisites

- OpenShift cluster with DevSpaces installed (from this demo)
- Web browser (Chrome, Firefox, Safari)
- No local tools required

### Step 1: Start Your Workspace

1. **Get the DevSpaces URL**:
   ```bash
   oc get route devspaces -n openshift-devspaces -o jsonpath='{.spec.host}'
   ```

2. **Open the workspace creation URL**:
   ```
   https://<DEVSPACES_URL>/#https://github.com/YOUR_USERNAME/rh-jboss-demo
   ```
   
   This automatically:
   - Creates a workspace
   - Clones the Git repository
   - Loads the devfile configuration
   - Starts the development containers

3. **Wait for workspace to start** (~60-90 seconds):
   - You'll see a loading screen
   - Once ready, you'll see VS Code in your browser

### Step 2: Explore the Workspace

**Left Sidebar**: File explorer
- Navigate to `components/kitchensink/src/`
- Explore the Java source code

**Bottom Panel**: Integrated terminal
- Pre-configured with Maven, Java, Git
- Current directory: `/projects/rh-jboss-demo`

**Top**: Editor area
- Click files to open them
- Full syntax highlighting and IntelliSense

### Step 3: Build the Application

In the terminal:

```bash
cd components/kitchensink
mvn clean package -DskipTests
```

**What this does**:
- Compiles Java source code
- Runs Bean Validation on entities
- Packages as a WAR file
- Output: `target/kitchensink.war`

**First build**: 5-7 minutes (downloads all Maven dependencies)
**Subsequent builds**: 30-60 seconds (dependencies cached)

**Watch for**:
```
[INFO] BUILD SUCCESS
[INFO] Total time: 42.5 s
```

### Step 4: Start JBoss with Hot-Reload

```bash
mvn wildfly:run -Dwildfly.dev
```

**What this does**:
- Starts JBoss EAP 7.4
- Deploys the kitchensink WAR
- Enables **development mode** (`-Dwildfly.dev`)
- Watches source files for changes

**Wait for**:
```
[INFO] WFLYSRV0025: WildFly Full 7.4.0.GA started in 15234ms
```

**Startup time**: 30-45 seconds

### Step 5: Access the Running Application

1. **Look for the notification**:
   - Top-right corner: "A service is available on port 8080"
   - Click "Open in New Tab"

2. **Or get the URL manually**:
   - In the terminal, look for: `Listening on http://0.0.0.0:8080`
   - DevSpaces exposes this as a public route

3. **You should see**:
   - Kitchensink welcome page
   - Member registration form
   - Empty member list

### Step 6: Test the Application

**Register a member**:
- Name: `John Doe`
- Email: `john@example.com`
- Phone Number: `5555551234`
- Click "Register"

**Verify**:
- Member appears in the table below
- Success message shows

### Step 7: Make a Code Change (Frontend)

**Edit the welcome message**:

1. Open: `src/main/webapp/index.xhtml`

2. Find line ~32:
   ```html
   <h1>Welcome to JBoss!</h1>
   ```

3. Change to:
   ```html
   <h1>Welcome to Modern JBoss Development!</h1>
   ```

4. **Save the file** (`Cmd+S` or `Ctrl+S`)

5. **Watch the terminal**:
   ```
   [INFO] File change detected: index.xhtml
   [INFO] Reloading application...
   [INFO] Reloaded in 1.8 seconds
   ```

6. **Refresh the browser tab** with the application

7. **See the change**: New heading appears

**Time from save to visible**: ~3 seconds

### Step 8: Make a Code Change (Backend)

**Add a new field to the Member entity**:

1. Open: `src/main/java/org/jboss/as/quickstarts/kitchensink/model/Member.java`

2. Add a new field after `phoneNumber`:
   ```java
   @Size(max = 100)
   @Column(name = "company")
   private String company;

   // Add getter and setter
   public String getCompany() {
       return company;
   }

   public void setCompany(String company) {
       this.company = company;
   }
   ```

3. **Save the file**

4. **Watch the terminal**:
   ```
   [INFO] File change detected: Member.java
   [INFO] Recompiling...
   [INFO] Reloaded in 2.3 seconds
   ```

**Note**: For entity changes with H2 (in-memory database), you may need to restart the server to recreate the schema. But for most code changes (service layer, REST endpoints, UI), hot-reload works instantly.

### Step 9: Make a REST API Change

**Modify the REST endpoint**:

1. Open: `src/main/java/org/jboss/as/quickstarts/kitchensink/rest/MemberResourceRESTService.java`

2. Find the `listAllMembers()` method

3. Add logging:
   ```java
   @GET
   @Produces(MediaType.APPLICATION_JSON)
   public List<Member> listAllMembers() {
       System.out.println("Fetching all members via REST API");
       return repository.findAllOrderedByName();
   }
   ```

4. **Save the file**

5. **Watch terminal**: Should see reload message

6. **Test**: In the app, refresh the page

7. **See the log** in terminal:
   ```
   Fetching all members via REST API
   ```

**Time**: ~2 seconds from save to working

### Step 10: Compare to Old Workflow

**Old WebSphere workflow** (for same change):
1. Edit file in Eclipse (1 sec)
2. Save (1 sec)
3. Eclipse publishes to WebSphere (60-120 sec)
4. WebSphere detects change (30 sec)
5. Undeploy old version (30 sec)
6. Deploy new version (60 sec)
7. Restart application (30 sec)
8. **Total**: ~5 minutes

**New DevSpaces workflow**:
1. Edit file (1 sec)
2. Save (1 sec)
3. Hot-reload (2 sec)
4. **Total**: ~5 seconds

**Time saved per change**: 4 minutes 55 seconds (98% reduction)

---

## Option 2: VS Code + odo (Local IDE)

For developers who prefer working in their local IDE.

### Prerequisites

- VS Code installed locally
- `oc` CLI installed and logged into OpenShift
- `odo` CLI installed

### Step 1: Install odo CLI

**macOS**:
```bash
curl -L https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/odo/latest/odo-darwin-amd64 -o odo
chmod +x odo
sudo mv odo /usr/local/bin/
odo version
```

**Linux**:
```bash
curl -L https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/odo/latest/odo-linux-amd64 -o odo
chmod +x odo
sudo mv odo /usr/local/bin/
odo version
```

**Windows**:
```powershell
# Download from: https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/odo/latest/odo-windows-amd64.exe
# Rename to odo.exe and add to PATH
```

### Step 2: Clone the Repository Locally

```bash
git clone https://github.com/YOUR_USERNAME/rh-jboss-demo
cd rh-jboss-demo/components/kitchensink
```

### Step 3: Open in VS Code

```bash
code .
```

**VS Code will**:
- Detect it's a Java project
- Load the `.vscode/settings.json` configuration
- Offer to install recommended extensions (Java Extension Pack)

**Install recommended extensions**:
- Language Support for Java
- Debugger for Java
- Maven for Java

### Step 4: Start odo Dev Mode

In VS Code terminal:

```bash
odo dev
```

**What odo does**:
1. Creates a temporary component in OpenShift
2. Builds the application in a pod
3. Starts JBoss EAP with your code
4. Watches local files for changes
5. Automatically syncs changes to the pod
6. Forwards port 8080 to `localhost:8080`

**Initial startup**: ~90 seconds

**Wait for**:
```
Watching for changes in the current directory
✓  Web console accessible at http://localhost:8080
Press Ctrl+c to exit `odo dev` and delete resources from the cluster
```

### Step 5: Access the Application

Open browser: `http://localhost:8080`

**You should see**: Kitchensink application running

**But it's not actually running locally**:
- The app is running in a pod in OpenShift
- odo forwards the port to your localhost
- You develop locally, run remotely

### Step 6: Make Changes with Auto-Sync

**Edit a file** (same as DevSpaces):

1. Open `src/main/webapp/index.xhtml`
2. Change the heading
3. Save (`Cmd+S`)

**odo automatically**:
- Detects the file change
- Syncs it to the pod
- Triggers hot-reload in JBoss

**Terminal output**:
```
File /src/main/webapp/index.xhtml changed
Pushing files...
✓  File sync completed in 1.2s
```

**Refresh browser**: See the change

**Time**: ~3-5 seconds

### Step 7: Make Java Code Changes

**Edit a Java file**:

1. Open `src/main/java/.../rest/MemberResourceRESTService.java`
2. Add a log statement
3. Save

**odo syncs and recompiles**:
```
File changed: MemberResourceRESTService.java
Pushing files...
Rebuilding...
✓  Changes applied in 2.8s
```

**Test the API**:
```bash
curl http://localhost:8080/rest/members
```

**See your log** in odo terminal output

### Step 8: Debug the Application

**Set up debugging in VS Code**:

1. Open `.vscode/launch.json` (already configured)
2. Set a breakpoint in `MemberResourceRESTService.java`
3. In VS Code: Run → Start Debugging (F5)

**VS Code connects** to the remote JBoss debug port via odo

4. In browser, navigate to the app
5. **Breakpoint hits** in VS Code
6. Inspect variables, step through code

**You're debugging** a remote application in OpenShift from your local IDE

### Step 9: Stop odo Dev Mode

In the terminal: `Ctrl+C`

**odo cleans up**:
- Deletes the temporary component from OpenShift
- Stops port forwarding
- No resources left behind

---

## Comparison: DevSpaces vs VS Code + odo

| Feature | DevSpaces | VS Code + odo |
|---------|-----------|---------------|
| **Where it runs** | Browser | Local IDE |
| **Setup required** | None | Install odo + VS Code |
| **Works offline** | No | No (syncs to cluster) |
| **Performance** | Fast | Fast |
| **Hot-reload speed** | 2-5 seconds | 3-5 seconds |
| **Debugging** | Yes (browser) | Yes (local debugger) |
| **Extensions** | Limited (browser) | Full VS Code ecosystem |
| **Device flexibility** | Any device with browser | Laptop/desktop only |
| **Team consistency** | Identical for all devs | Can vary by dev setup |
| **Best for** | Onboarding, demos, quick edits | Daily development by experienced devs |

**Recommendation**: 
- Use **DevSpaces** for onboarding and demos (zero setup)
- Use **VS Code + odo** for daily development (familiar IDE)
- Both provide the same 98% time savings vs traditional workflow

---

## What Gets Hot-Reloaded?

### ✅ Hot-Reload Works (No Restart Needed)

- **UI changes** (XHTML, CSS, JavaScript)
- **Java classes** (service layer, REST endpoints)
- **CDI beans** (most changes)
- **Static resources** (images, HTML)
- **Bean Validation** annotations
- **JAX-RS** endpoints

**Time**: 1-3 seconds

### ⚠️ Requires Restart

- **pom.xml** changes (new dependencies)
- **persistence.xml** changes (JPA config)
- **Entity schema changes** (adding fields to `@Entity` with H2)
- **beans.xml** changes (CDI configuration)
- **Application server configuration**

**Time**: 30-45 seconds (still faster than traditional workflow)

**To restart**:
- **DevSpaces**: `Ctrl+C` in terminal, then `mvn wildfly:run -Dwildfly.dev` again
- **VS Code + odo**: `Ctrl+C`, then `odo dev` again

---

## Troubleshooting

### Hot-Reload Not Working

**Symptom**: Change file, save, but change doesn't appear

**Diagnosis**:
1. Check terminal - is `mvn wildfly:run -Dwildfly.dev` running?
2. Look for `-Dwildfly.dev` flag (NOT just `mvn wildfly:run`)
3. Check for error messages in terminal

**Solution**:
```bash
# Stop the server (Ctrl+C)
# Restart with dev mode
mvn wildfly:run -Dwildfly.dev
```

### Maven Build Fails

**Symptom**: "BUILD FAILURE" during `mvn package`

**Common Causes**:
1. **Compilation error**: Fix the Java syntax error
2. **Missing dependency**: Check `pom.xml`
3. **Out of memory**: Increase MAVEN_OPTS

**Solution for memory**:
```bash
export MAVEN_OPTS="-Xmx1g"
mvn clean package
```

### DevSpaces Workspace Won't Start

**Symptom**: Workspace stuck on "Starting..."

**Diagnosis**:
```bash
# Find your workspace pod
oc get pods -n <your-username>-devspaces

# Check logs
oc logs <workspace-pod> -n <your-username>-devspaces
```

**Common Causes**:
- Not enough cluster resources
- Image pull errors
- PVC mount issues

**Solution**: Delete workspace and recreate, or contact cluster admin

### odo: "Component already exists"

**Symptom**: `odo dev` says component already exists from previous run

**Solution**:
```bash
# Delete the component
odo delete component --force

# Try again
odo dev
```

### Port 8080 Already in Use (Local)

**Symptom**: odo can't forward port 8080

**Solution**:
```bash
# Find what's using port 8080
lsof -i :8080

# Kill it, or use a different port
odo dev --forward-localhost-port 8081
```

Then access: `http://localhost:8081`

---

## Measuring the Impact

### Developer Time Savings Calculator

**Inputs**:
- Changes per day: 50
- Old workflow time: 5 minutes/change
- New workflow time: 5 seconds/change

**Calculations**:

Old way: 50 × 5 min = 250 minutes/day = **4.2 hours waiting**

New way: 50 × 5 sec = 250 seconds/day = **4 minutes waiting**

**Time saved**: 4.2 hours - 0.07 hours = **4.13 hours/day/developer**

**For a team of 10 developers**:
- Daily savings: 41.3 hours
- Weekly savings: 206.5 hours (~5 full-time weeks)
- Yearly savings: 10,738 hours (~5.4 FTEs)

**Productivity gain**: ~50% more time spent coding vs waiting

### ROI Example

**Scenario**: Team of 10 developers, $100k average salary

**Old workflow**:
- 4.2 hours/day waiting
- ~50% of time non-productive
- Effective team size: 5 developers

**New workflow**:
- 4 minutes/day waiting
- ~98% of time productive
- Effective team size: 9.8 developers

**Gain**: 4.8 additional full-time developers' worth of productivity

**Value**: $480k/year in reclaimed productivity

**Setup cost**: ~40 hours to implement (this demo) = $10k

**ROI**: 4,800% in first year

---

## Next Steps

### For Evaluation

1. **Try both options** (DevSpaces and VS Code + odo)
2. **Measure your own metrics**:
   - Time 5 code changes in your current workflow
   - Time the same 5 changes with hot-reload
   - Calculate your specific savings

3. **Test with your application**:
   - Use the same hot-reload approach
   - Adapt the devfile/configuration for your app
   - Measure impact on your development team

### For Adoption

1. **Run a workshop** with your development team (4 hours)
2. **Pilot with one team** on one application
3. **Measure results** after 2 weeks:
   - Developer satisfaction survey
   - Actual time savings
   - Deployment frequency increase

4. **Scale across teams** based on pilot success

### For Production

1. **Add production database** (PostgreSQL/MySQL/Oracle)
2. **Configure environment-specific settings**
3. **Set up multi-environment pipelines** (dev → test → prod)
4. **Integrate monitoring and logging**
5. **Train teams on troubleshooting**

---

## Resources

- [WildFly Maven Plugin Dev Mode](https://docs.wildfly.org/wildfly-maven-plugin/dev-mojo.html)
- [odo Documentation](https://odo.dev/)
- [OpenShift DevSpaces](https://docs.openshift.com/devspaces/)
- [Devfile Specification](https://devfile.io/)
- [JBoss EAP Hot Deployment](https://access.redhat.com/documentation/en-us/red_hat_jboss_enterprise_application_platform/7.4/html/configuration_guide/deployment_scanner_subsystem)

Happy coding with hot-reload! 🚀
