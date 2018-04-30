# Using Mocha, Testrail, and Jenkins Together
  
This is a sandbox for integrating `mocha`, `testrail`, and `jenkins`.

## Jenkins

### First Time Setup

These steps should only need to be performed once locally, provided that you don't delete your `jenkins_home` directory. It's linked to the container using a volume, so it should store all of your local configurations.

If for some reason the `jenkins_home` volume isn't working, you can copy your container's Jenkins configuration to your local machine using this command:

```
docker cp $CONTAINER_ID:var/jenkins_home/ jenkins_home
```

#### Bring Up Docker Container and Provide Admin Password

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

Navigate to `localhost:8080` and provide the password on the "Unlock Jenkins" screen.

#### Install Plugins

Ensure that the following plugins are installed:

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

**Note**: All of these except `NodeJs Plugin` will be installed by choosing the default plugins at startup.

#### Set Up Credentials

- On the GitHub account that will execute builds, create a "Personal access token" for Jenkins `https://github.com/settings/tokens`
- On the Jenkins web application, click "Credentials".
- Under "Stores scoped to Jenkins", click "Jenkins".
- Under "System", click "Global credentials (unrestricted)".
- Click "Add Credentials" to create new credentials.

You'll need to add two sets of credentials:
- Kind: Secret Text => the Personal access token created above
- Kind: Username with password => the GitHub username / password of the account that created the Personal access token

#### Set Up Node

In order to use `npm install` in our Jenkins build, we need to configure the server to use node.

- Go to `localhost:8080/configureTools`.
- Under "NodeJs", click "Add NodeJS".
- Give it any name and select a version.
- Restart Jenkins (`http://localhost:8080/restart`)

Resource: https://wiki.jenkins.io/display/JENKINS/NodeJS+Plugin

#### Create New Job

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

*If the Node Build Environment option is not available, double-check that the "Set Up Node" steps were completed.

#### Resources

This link contains the original instructions I adapted from, though there were some gaps:
https://www.terlici.com/2015/09/29/automated-testing-with-node-express-github-and-jenkins.html


### Connect Jenkins to GitHub

Since this repo uses a local instance of Jenkins, we need to set up a static URL that forwards to `localhost` (GitHub won't be able to connect to it otherwise).

Install `ngrok` and create a new account, if you haven't already done so.

In a terminal, run:

```
ngrok http 8080
```

The static URL will be displayed in the terminal.

To connect GitHub to the Jenkins instance:
- On the GitHub repository page, click "Settings", then "Integrations and Services".
- Click "Add Service" => "Jenkins (GitHub Plugin)"
- In the field "Jenkins hook url", paste in `https://###-ngrok.io/github-webhook/`*, where ###-ngrok.io is your ngrok host.**
- Make sure that "Active" is checked.
- Save the service.

Once the service is created, click "Test service" on the upper right of the panel to test it. From the Jenkins project, you should be able to click "GitHub Hook Log" on the left side and see some text output from the test call. This will tell you that everything is set up correctly.

*The trailing `/` on this URL is **super important**; your service won't work without it.
**If you are on a free ngrok account, you'll need to update your GitHub service each time your ngrok URL changes.

## Testrail

### First Time Set Up

- go to the [testrail](https://secure.gurock.com/customers/testrail/trial/) website and download the  `.zip` (server version - php5) - you'll need to sign up for the trial
- put the `.zip` file in the project's `/docker/testrail` directory

### Run Locally

```
docker-compose up -d testrail
```

- check the logs - it should say "Starting web server apache2" after a couple of seconds.
- open `localhost:7070/testrail`
- login name: `admin@admin.com` / password: `admin`

### Create Test Cases and Link Them to Mocha

- in the browser instance of testrail, click the "My Project" project
- click the "Test Cases" tab
- click "Add Case" and give it a name
- update the `it` block of a `mocha` test to contain that id.

For example, if the test case id is "C1", do this:

```js
it('C1 should do something', function () {
  ...
});
```

If you run the tests and see this message, you need to link test cases:

```
Publishing 0 test result(s) to http://testrail/testrail/index.php
Results published to http://testrail/testrail/index.php?/runs/view/4
Error: {"error":"Field :results cannot be empty (one result is required)"}
```

### Run Tests Send Test Results to Testrail

Source `TESTRAIL_LOGIN_EMAIL` and `TESTRAIL_LOGIN_PASSWORD`:

```
export TESTRAIL_LOGIN_EMAIL=admin@admin.com
export TESTRAIL_LOGIN_PASSWORD=admin
```

Finally, run the tests:

```
./bin/test e2e --build --testrail
```

If this completes successfully, you should see this message in the console:

```
Publishing 1 test result(s) to http://testrail/testrail/index.php
Results published to http://testrail/testrail/index.php?/runs/view/3
```

The run should also be visible on `localhost:7070/testrail` under the "Test Runs" tab.

### Backup Testrail Database

You can copy docker's testrail database to your local machine in order to modify and check in the "seed" database.

```
docker-compose up -d testrail
docker exec mocha-jenkins-testrail_testrail_1 /usr/bin/mysqldump testrail > ./docker/testrail/testrail.sql
```

### Other Resources
[mocha-testrail-reporter](https://www.npmjs.com/package/mocha-testrail-reporter)
[Staging TestRail with Docker](http://philipson.co.il/post/taming-a-legacy-application-with-docker/)
[testrail-docker (working fork)](https://github.com/bannmoore/testrail-docker)

### Issues

mysql doesn't start - https://github.com/docker/for-linux/issues/72#issuecomment-319904698
