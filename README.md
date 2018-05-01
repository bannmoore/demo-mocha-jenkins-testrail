# Continuous Integration: Mocha + TestRail + Jenkins
  
This repo demonstrates a continuous integration workflow for JavaScript projects. This repo can be used locally as a POC, but it requires quite a bit of set up. If you already have server instances of Jenkins and/or TestRail, you can skip most of the steps.

```
When changes are pushed to GitHub, execute Mocha tests in Jenkins and publish the results to TestRail.
```

## What You'll Need:

- A GitHub repository with Mocha tests and `mocha-junit-reporter` as a dependency (feel free to fork or copy this one)
- A Jenkins instance*
- A TestRail instance*

*Follow the steps below to set up a local instance

## TestRail Local Set Up

There isn't currently a preset `TestRail` container in docker (probably because the server version requires a subscription), so you'll need to download a copy of the installer. This will also require signing up for a free trial of TestRail.

- Go to the [TestRail site](http://www.gurock.com/testrail/)
- Click "Try TestRail For Free"
- Select "TestRail Server" and create an account
- Download the `php5` version of the TestRail `.zip` file
- Place the `.zip` file in this project's `/docker/testrail` directory

Now, bring up the `testrail` container:

```
docker-compose up -d testrail
```

If you check the logs (`docker-compose logs testrail`), it should say "Starting web server apache2" after a couple of seconds. If all goes well, open the browser to `http://localhost:7070` and login.

The credentials are:

```
username: admin@admin.com
password: admin
```

The file `docker/testrail/testrail.sql` preloads a configuration into TestRail, so the server will start with a demo project ready to go.

### Save TestRail Configuration

If at any point you want to save your local TestRail configuration (new projects, test cases, etc.), you can use this command to copy the container's data to your local:

```
docker-compose up -d testrail
docker exec mocha-jenkins-testrail_testrail_1 /usr/bin/mysqldump testrail > ./docker/testrail/testrail.sql
```

### Other Resources

- [Staging TestRail with Docker](http://philipson.co.il/post/taming-a-legacy-application-with-docker/)
- [testrail-docker (working fork)](https://github.com/bannmoore/testrail-docker)

## Jenkins Local Set Up

Most of Jenkins' data resides in `/var/jenkins_home` on the docker container. The `jenkins` service in this repo sets up a volume between that folder and `testrail/jenkins/jenkins_home` in this repo, so once you've performed the set up once you shouldn't need to do it again.

If you don't want to lose your configuration, _don't_ delete `docker/jenkins/jenkins_home`.

### Bring Up The Container and Provide The Admin Password

```
docker-compose up jenkins
```

Look for this section in the logs to retrieve the admin password:

```
jenkins_1   | Please use the following password to proceed to installation:
jenkins_1   |
jenkins_1   | *SOME_PASSWORD_STRING*
jenkins_1   |
jenkins_1   | This may also be found at: /var/jenkins_home/secrets/initialAdminPassword
```

Navigate to `localhost:8080` and provide the password on the "Unlock Jenkins" screen. Choose the option that auto-installs plugins for you and wait for it to finish.

### Generate a Static URL for Jenkins

Since this repo uses a local instance of Jenkins, we need to set up a static URL that forwards to `localhost` (GitHub won't be able to connect to it otherwise).

Install `ngrok` and create a new account, if you haven't already done so.

In a terminal, run:

```
ngrok http 8080
```

The static URL will be displayed in the terminal. Use this instead of `localhost` to connect GitHub to Jenkins.

## Connect GitHub to Jenkins

Now that you have Jenkins and TestRail running (either locally or on a server), we can set up the CI process. In this section, we'll connect Jenkins to our GitHub repository and tell GitHub to push changes to Jenkins.

### Create Personal access token

On the GitHub account that will send builds to Jenkins, create a "Personal access token" at this URL: `https://github.com/settings/tokens`. The token needs `admin:repo_hook`, `repo`, and `repo:status` permissions.

The token will only be displayed once, so make sure you copy it for later use.

### Verify Plugins

In the Jenkins web UI, click "Manage Jenkins", then "Manage Pulgins", and ensure that the following plugins are installed:

- Credentials Plugin
- Git Plugin
- GitHub Plugin
- JUnit Plugin
- Mailer Plugin
- Matrix Authorization Strategy Plugin
- Plain Credentials Plugin
- SSH Credentials Plugin
- SSH Slaves plugin
- NodeJS plugin

### Create GitHub Credentials

Next, we'll need to store the GitHub credentials in Jenkins.

- In Jenkins, click "Credentials".
- Under "Stores scoped to Jenkins", click "Jenkins".
- Under "System", click "Global credentials (unrestricted)".
- Click "Add Credentials" to create new credentials.

You'll need to add two sets of credentials:

- Kind: Secret Text => the Personal access token created above
- Kind: Username with password => the GitHub username / password of the account that created the Personal access token

### Set Up Node 
 
In order to use `npm install` in Jenkins, it has to be configured with `Node`.

- Go to `localhost:8080/configureTools`.
- Under "NodeJs", click "Add NodeJS".
- Give it any name and select a version.
- Restart Jenkins (`http://localhost:8080/restart`)

Resource: https://wiki.jenkins.io/display/JENKINS/NodeJS+Plugin

### Create New Job

Next, we'll create a Job that communicates with GitHub and executes the tests.

- On the Jenkins web page, click "New Item".
- Provide any name and select "Freestyle project", then Click "OK".
- On the configuration page:
  - Under "General": select "GitHub project" and paste in the URL to the GitHub repository.
  - Under "Source Code Management": select "Git". Paste in the repository URL and select the username/password credentials created earlier.
  - Under "Build Triggers", select "GitHub hook trigger for GITScm polling"
  - Under "Build Environment", select "Provide Node & npm bin/folder to PATH"* and choose the NodeJS installation created earlier.
  - Under "Build", select "Add build step" => "Execute shell" and paste in the script below.
  - Under "Post-build actions", select "Add post-build action" => "Publish JUnit test result report" and provide a name for "Test report XMLs" (`jenkins-test-results.xml`).
  - Click "Save"

``` 
# Execute shell script
npm install
MOCHA_FILE=./jenkins-test-results.xml ./node_modules/.bin/mocha test --recursive --reporter mocha-junit-reporter
```

**Note**: This command assumes that your GitHub repository meets the following criteria:
- Mocha tests reside in the `test` directory
- `mocha-junit-reporter` is listed as a dependency or devDependency

The JUnit reporter is necessary to properly convert Mocha results to an XML format Jenkins understands.

### Add Service to GitHub

Finally, we need to tell the GitHub repository to send updates to the Jenkins instance.

- On the GitHub repository page, click "Settings", then "Integrations and Services".
- Click "Add Service" => "Jenkins (GitHub Plugin)"
- In the field "Jenkins hook url", paste in `https://jenkins-host/github-webhook/`, where jenkins-host is your server's host*.
- Make sure that "Active" is checked.
- Save the service.

Once the service is created, click "Test service" on the upper right of the panel to test it. From the Jenkins project, you should be able to click "GitHub Hook Log" on the left side and see some text output from the test call. This will tell you that everything is set up correctly.

**Note**: The trailing / on the Jenkins URL is super important; your service **won't work without it**.

*If you are using a local instance of Jenkins with `ngrok`, this URL will change _every_ time you restart `ngrok`.

## Connect Jenkins to TestRail

We'll be using the Jenkins [TestRail Plugin](https://github.com/jenkinsci/testrail-plugin) to send Jenkins results to TestRail. This plugin is not installable via the Plugin Manager, so you'll need to get ahold of the `.hpi` file and install it manually using the web UI.

**Note**: You can use the `build-testrail-plugin.sh` script in this repo to get a local version of the `.hpi` file.

Once you have the `.hpi`:

- In Jenkins, click "Manage Jenkins" => "Manage Plugins"
- Select the "Advanced" tab
- Use the "Upload Plugin" section to upload the `.hpi` file

After the TestRail Plugin is installed:

- From the main dashboard, click "Manage Jenkins" => "Configure Systems"
- Scroll down to the "Testrail" section and provide host, username, and password for Testrail
  - The "host" will need to match the link we created between testrail and jenkins using Docker (`http://testrail`).
- Go to the tests job configuration page and scroll down to "Post-build Actions"
- Click "Add post-build action" => "Notify TestRail"
- Fill in "Test Report XMLs" with the filename of the test results (you can find this in "Workspaces")

## Try it Out

Once all these steps are completed, you should have a working CI process. Pushing changes to GitHub should trigger a test run in Jenkins, which is then sent to TestRail. Tada!

## Other Resources

This link contains the original instructions I adapted from, though there were some gaps:
https://www.terlici.com/2015/09/29/automated-testing-with-node-express-github-and-jenkins.html

