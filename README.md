# jenkins-docker-build-cluster

## Purpose and Process

This project is a research use case to develop a uniform developer deployment instance of Jenkins and Docker running in in a Docker container

Why use docker to run Jenkins
A. Everyone will have the same container image of Jenkins
B. Operating system agnostic 
  -> Can run Docker on Ubuntu in Digital Ocean, AWS, Google Cloud, or Azure. 
  -> Can run locally on Mac, Windows, etc
C. Can easily upgrade Jenkins by pulling latest Docker Image and can modify the Jenkins container image by creating a Dockerfile

The purpose is to provide an automated environment for developers to deploy and test code that can be built in all environments including
Dev, Test, QA, and production (**CAUTION: This test package is not secure at this time and SHOULD NOT be used to deploy production grade code)

The concept is to have an automated package that can be deployed that standardizes the Jenkins and Docker versions and global tools across environments and platforms. Using a container, a developer or devops engineer can quickly deploy Jenkins and Docker on Windows, Linux, or MAC and have the same toolset to test code.

## Scalability

The concept of using Jenkins and Docker inside a container is useful for a single developer or scrum team.  In order for it to be a viable
option for entire teams or departments, it must be scalable to eliminate performance issues.  While the premise to keep this cloud, environmentent, and operating system agnostic, the project has been configured to deploy to AWS as autoscale group.

The project uses several AWS tools including:
1. AWS Launch Configuration
2. AWS Autoscaling
3. AWS Load Balancing
4. Custom Security Groups
5. AWS VPC

The basic premise is the ASG is deployed with a minimum of two EC2 instances and can scale to a maximum of ten instances as demand increases. Please review jenkins_build_cluster.tf for more in depth details pertaining to the code used.

```
resource "aws_autoscaling_group" "buiLd-server-asg" {
    launch_configuration    = aws_launch_configuration.jenkinsdocker-asg.name
    vpc_zone_identifier     = data.aws_subnet_ids.default.ids

    target_group_arns       = [aws_lb_target_group.asg.arn]
    health_check_type       = "ELB"                         
    # Use type ELB rather than EC2. ELB uses the target group health check rather than AWS instance health check
    
    min_size = 2
    max_size = 10
```

## Deployment

Intial deployment to AWS can be done from the AWS-CLI command line tool.

![](images/AWScli.png)
 




## The use case will consist of three phases and each one is defined below.

1. The basic concept of deploying Jenkins and Docker to a Linux vm in a Docker container to build and test a basic nodejs application. This test will verify the fundamental theory that Jenkins and Docker can be used to deploy code via a container.

2. The second phase will add a basic Jenkinsfile and Dockerfile to the process.

3. The third phase will introduce a Terraform element to build infrastructure in AWS and deploy code to an EC2 instance and completely automate the process, eliminating the need for phase 1 and 2 altogether.

The following explains the basic structure of the Jenkins and Docker container deployment as well as the Jenkinsfile and Terraform methodology.

Phase 1 and 2 were built using a basic Digital Ocean Ubuntu v16.04.06 machine to install Jenkins and Docker in a container. In addition to using Digital Ocean, Github and Dockerhub were used.

Jenkins and Docker were "Containerized" using a script formed from basic Linux commands and can be veiwed here: https://github.com/mabrahamdevops/scripts.git

1. Digital Ocean hosts Jenkins and Docker within a Docker container
2. Install Jenkins and Docker from repository script: wget https://github.com/wardviaene/jenkins-course/tree/master/scripts/install_jenkins_docker.sh
3. Run -> bash install_jenkins_docker.sh
4. In a browser (Chrome was used for initial testing) test access to Jenkins at the address given after script runs. You should be presented with the "Unlock Jenkins" screen
5. Use cat to navigate to the password file to obtain initial password -> cat /var/jenkins_home/secrets/initialAdminPassword

After initial installation, some plugins and global tools will need to be installed. There are several ways to use Docker plugins and tools with Jenkins.

1. In Jenkins, go to Manage Jenkins > Manage Plugins. Click the "Available" tab and search "docker" There are several Docker plugins so one can research the best
   plugin for your use case. For this use case the “CloudBees Docker Build and Publish plugin” was used.
2. Ensure you can execute docker and access the docker API on the Jenkins machine.
3. From there, clone the Jenkins docker repo > https://github.com/wardviaene/jenkins-docker
   a. git clone https://github.com/wardviaene/jenkins-docker
   b. Change directory to Jenkins-docker
   c. Build the container > “docker build -t jenkins-docker .”
   d. We will not need the original Jenkins image at this point so we can remove it.
   e. Run “docker stop Jenkins”
   f. Run “docker rm jenkins”

4. Now run the container uploaded in the above step a. which is “Jenkins-docker” using this command:
   docker run -p 8080:8080 -p 50000:50000 -v /var/jenkins_home:/var/jenkins_home -v /var/run/docker.sock:/var/run/docker.sock --name jenkins -d jenkins-docker
   a. Confirm with docker ps -a
   b. Test that the Jenkins user has access to the docker socket (docker.sock)
   c. Verify its owned by root with “ls -ahl /var/run/docker.sock”
   d. Test access of container before using in Jenkins -> “docker exec -it jenkins bash”
   e. Repeat commands in step c. and d. inside the container

5. Add the Docker Build and Publish step to the Jenkins freestyle job (To get a docker account and upload the docker image repo go to https://hub.docker.com and sign up.)
   a. Add “Repository Name”. In this example it is “mabrahamdevops/docker-nodejs-demo” or you can clone the my repos and create new file paths in the Jenkinsfile
   b. Add “Registry credentials” This will be the docker hub user name and password.  
    - Go to Jenkins -> Credentals -> under Domain, click the drop down under (global), click Add credential. Add dockerhub as "ID" and your Dockerhub username and password.

For step a. above, you will need to create a new docker repository on docker hub
--If docker and Jenkins are running on the same machine, this is the easiest setup.  
 --If Jenkins is on a separate build server, from Docker Build and Publish, you can select “Docker installation”, select Docker. You will need to go to Global Tools Configuration to install Docker.  
 Access rules may be needed for the docker socket connections.

The final step is to test the Nodejs application docker image on the Blue Ocean machine.

1. Run “docker pull mabrahamdevops/jenkins-docker-demo”
   a. You will see a status confirmation: “Status: Image is up to date for mabrahamdevops/jenkins-docker-demo:latest
   docker.io/mabrahamdevops/jenkins-docker-demo:latest”
2. Run “docker run -p 3000:3000 -d –name my-nodejs-app mabrahamdevops /docker-nodejs-demo”
3. Run “docker ps” > confirm the container is running.
4. Finally, run “curl localhost:3000” to run the app or in a browser, type in the IP address:port number (http://64.227.25.13:3000/). Both options will return “Hello World!”

### The following section explains the Jenkinsfile line by line. Refer to the Jenkinsfile located in the "cm" folder in the following repository:

https://github.com/mabrahamdevops/jenkins-docker-demo.git

The theory here is to start with a basic Jenkinsfile and as use case testing progresses, more functionality will be added.

Line 1: build on any node

Line 2: variable: commit_id. Jenkins does not expose this by default in pipeline

Line 3: preparation stage begins

Line 4: git clone of this repository into Jenkins

Line 5: this shell command will give you the commit id and place it in the file .git/commit-id

Line 6: save the commit id and read from the temp file. Trim any spaces or special characters

Line 7: end block for Preparation stage

Line 8: test stage begins

Line 9: tells Jenkins to use the nodejs tool installed in Global Tool configuration. Otherwise npm we would throw the error "npm not found".

Line 10: run npm install but only the development package that is referenced in the "package.json" file. In this case the
development package is “mocha”. This package is needed as a dependency of running the test package
Line 11: npm test will run the executable “mocha” referenced in the package.json file

**This test.js file is a generic and borrowed test that will run and always succeed. Typically, the developer will provide the test references needed for the application.**

Lines 12 and 13: end block for test stage

Line 14: docker build/push stage begins

Line 15: points to the standard docker registry and will use the Docker Hub credentials set in Jenkins

Line 16: build the docker image, tag with the registry name and commit id. Build in the current directory and push to the Docker registry

### <PLACEHOLDER FOR TERRAFORM METHODOLOGY>
