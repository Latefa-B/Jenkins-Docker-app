# Jenkins CI/CD - Docker to ECR and EKS Deployment
Jenkins is one of the most widely used and powerful tools in the DevOps world for implementing Continuous Integration (CI) and Continuous Delivery (CD) pipelines. As an open-source automation server, it enables teams to build, test, and deploy software efficiently through automated workflows. Highly extensible by design, Jenkins supports a vast range of plugins that integrate seamlessly with various tools and technologies. It serves as a centralized automation platform that orchestrates and streamlines repetitive tasks involved in software development, such as : Building software (compiling code), Testing software (running automated tests), Deploying software (sending it to servers or Kubernetes clusters) and Monitoring the execution of these tasks. Enhancing productivity, consistency, and delivery speed.

Previously, we have built a solid foundation : Docker for containerization, Kubernetes for orchestration, Terraform for infrastructure, and Jenkins for automation. In this lab, we will combine these powerful tools into a complete, automated CI/CD pipeline orchestrated by Jenkins.

This comprehensive step-by-step guide walks you through the process of Deploying a containerized application to Kubernetes on AWS using Jenkins as a CI/CD engine. In this lab, your Jenkins Pipeline will:
- Pull application code from Git.
- Build a Docker image.
- Authenticate with AWS Elastic Container Registry (ECR).
- Push the Docker image to ECR.
- Configure kubectl to connect to your AWS EKS cluster.
- Deploy your application to EKS using kubectl (or a simple Helm command, if you prefer to skip Helm for now and use kubectl apply).

This project will demonstrate a common industry pattern for deploying containerized applications to Kubernetes in the cloud using Jenkins as your CI/CD engine. The aim of this lab is to learn : 
- How to integrate Jenkins with AWS services (ECR, EKS).
- How to configure Jenkins credentials for AWS access.
- How to build and push Docker images to AWS ECR from a Jenkins Pipeline.
- How to configure kubectl within a Jenkins Pipeline to interact with EKS.
- How to deploy a Kubernetes Deployment and Service to EKS from Jenkins.
- The end-to-end flow of a Jenkins-driven cloud-native CI/CD pipeline.

## Prerequisites
- Your Jenkins master server should be running and accessible (http://localhost:8080), with the Docker socket mounted (v /var/run/docker.sock:/var/run/docker.sock).
- app.py, Dockerfile, and Jenkinsfile files.
- Your AWS EKS cluster  should be running. 
- Your AWS ECR repository (my-flask-app-repo)
- An IAM User or Role with programmatic access (Access Key ID and Secret Access Key) with permissions to:
Push images to ECR (ecr:GetAuthorizationToken, ecr:BatchCheckLayerAvailability, ecr:CompleteLayerUpload, ecr:InitiateLayerUpload, ecr:PutImage, ecr:UploadLayerPart).
Interact with EKS (eks:DescribeCluster, eks:ListClusters).
- Assume the EKS worker node role (sts:AssumeRole) for kubectl to deploy.
- kubectl and aws-iam-authenticator should be installed on your Jenkins agent (or master, if running builds there). If using a jenkins/ssh-agent:lts Docker image, you'll need to add these.

## Step-by-step instructions
### Step 1: Prepare Your Jenkins Agent (or Master) for AWS and Kubernetes Tools
The Jenkins agent (or master, if you're running builds there) needs kubectl and aws-iam-authenticator to interact with EKS, and the AWS CLI to authenticate with ECR. We'll ensure these are available. To complete Step 1, follow the instructions below : 
- If using jenkins-agent Docker container : Stop and remove your existing jenkins-agent container using the commands line : docker stop jenkins-agent docker rm jenkins-agent
- Run a new agent container with kubectl and awscli pre-installed (or install them inside).
- Create a new folder jenkins-custom-agent using the command line : mkdir jenkins-custom-agent && cd jenkins-custom-agent
Note : The jenkins/ssh-agent:lts image is quite minimal. You'll need to create a custom Dockerfile for your agent or install these tools inside the running agent. Create a custom agent image:
Inside, create a Dockerfile and paste the content below.

- Build this image using the command : docker build -t jenkins-aws-k8s-agent .




**Error** : failed to build: failed to solve: process "/bin/sh -c apt-get update && apt-get install -y curl unzip python3 python3-pip && pip3 install awscli && apt-get clean && rm -rf /var/lib/apt/list s/*" did not complete successfully: exit code: 1.

**Explanation** : the Dockerfile build failed due to Linux distro rules . AWS CLI installation could be incompatible with python / pip. 

**Solution** : As an alternative, we have changed to Debian-based images that are more compatible with AWS CLI installation. 

**Troubleshooting steps** : 
**Step 1** : Replace the Dockerfile to a Debian based image instead of python / pip.

**Step 2** : Build the dockerfile using the command line : docker build -t jenkins-aws-k8s-agent .


- Run the custom agent using the command line : docker run -d --name jenkins-agent --init -v /var/run/docker.sock:/var/run/docker.sock jenkins-aws-k8s-agent

- Verify Agent Connection: Ensure your docker-agent node in Jenkins (http://localhost:8080/computer/docker-agent/) is "Online." If not, re-run the docker exec -d jenkins-agent java -jar ... command from Lab 4.


### Step 2: Create Jenkins Credentials for AWS Access
Jenkins needs your AWS Access Key ID and Secret Access Key to interact with AWS services like ECR and EKS. We'll store these securely in Jenkins's Credentials Manager. To complete Step 2, follow the instructions below : 
- Open your web browser and go to your Jenkins Dashboard (http://localhost:8080).
- In the left navigation, click "Manage Jenkins."
- Click "Plugins."
- Check "Available plugins." and look for AWS Credentials.
- Check “Installed plugins” and make sure the plugin is installed.
- In the left navigation, click "Manage Jenkins."
- Click "Credentials."
- In the left navigation, click "System."
- Click "Global credentials (unrestricted)."
- Click "Add Credentials."

- Fill in the details:
* Kind: "AWS Credentials" (You might need to install the "AWS Credentials plugin" if this option isn't available. Go to Manage Jenkins -> Plugins -> Available plugins, search for "AWS Credentials plugin").
* Scope: "Global"
* ID: aws-credentials (This is the ID you'll reference in your Jenkins job).
* Access Key ID: Your AWS Access Key ID.
* Secret Access Key: Your AWS Secret Access Key.
* Description: AWS credentials for ECR and EKS access
- Click "Create."

### Step 3: Update Jenkinsfile for AWS ECR and EKS Deployment
We will modify your Jenkinsfile to include stages for AWS authentication, Docker push to ECR, and Kubernetes deployment to EKS. To complete Step 3, follow the instructions below: 
- Navigate to your jenkins-git-app folder locally.
- Open your Jenkinsfile and Update it with the following content.

Note : 
* YOUR_DOCKERHUB_USERNAME: Your Docker Hub username (used for the local image name before retagging).
* YOUR_AWS_ACCOUNT_ID: Your AWS account ID.
* YOUR_AWS_REGION: Your AWS region (e.g., us-east-1).
* YOUR_EKS_CLUSTER_NAME: The name of your EKS cluster.
- Save Jenkinsfile.



- Commit and push the updated Jenkinsfile to your GitHub repository:
cd jenkins-git-app 
git add Jenkinsfile 
git commit -m "Add or Update Jenkinsfile for ECR and EKS deployment" 
git push origin <your-branch-name>

### Step 4: Configure Jenkins Pipeline Job
We'll reuse the Python-Docker-Pipeline job from Lab 3, but ensure it's configured to use our aws-credentials for AWS access. To complete Step 3, follow the instructions below : 
- Open your web browser and go to your Jenkins Dashboard (http://localhost:8080).
- Click on Python-Docker-Pipeline.
- In the left navigation, click "Configure."

- Ensure "Build Triggers" -> "GitHub hook trigger for GITScm polling" is checked.
- Ensure "Pipeline" -> "Definition:" is "Pipeline script from SCM" and points to your Git repository and Jenkinsfile.

- Add "Additional Behaviors" for AWS Credentials (if not automatically picked up by withCredentials):
- Scroll down to "Source Code Management" -> "Git."
- Click "Add" next to "Additional Behaviors."
- Select "Inject build environment variables."
- For "Credentials," select aws-credentials from the dropdown. This ensures the AWS credentials are available as environment variables for aws CLI commands.

- Click "Save."


### Step 5: Trigger Pipeline and Verify EKS Deployment
Make a small code change and push it. Jenkins will trigger the pipeline, build the Docker image, push it to ECR, and then deploy it to your EKS cluster. To complete Step 5, follow the instructions below : 
- Navigate to your jenkins-git-app folder locally.
- Open app.py and make a tiny, harmless change (e.g., update a comment).
- Commit and push this change to GitHub:
cd jenkins-git-app 
git add app.py 
git commit -m "Trigger full CI/CD pipeline to EKS" 
git push origin <your-branch-name>


- Observe in Jenkins:
- Go to your Jenkins Dashboard (http://localhost:8080).
- Click on Python-Docker-Pipeline. You should see a new build automatically start.
- Click on the build number.


- Click "Stage View." You'll see new stages: Push Docker Image to ECR and Deploy to EKS.






- Monitor the console output for each stage. The Deploy to EKS stage should show kubectl commands executing.





- Verify EKS Deployment:
- Once the Jenkins build finishes with SUCCESS, open your local terminal.
- Ensure your kubectl is configured to connect to your EKS cluster : aws eks update-kubeconfig --name YOUR_EKS_CLUSTER_NAME --region YOUR_AWS_REGION

- Check the deployed resources:
- kubectl get deployment jenkins-deployed-app
- kubectl get service jenkins-deployed-app-service

- Get the EXTERNAL-IP (DNS name) of your jenkins-deployed-app-service. It might take a few minutes for the AWS Load Balancer to provision.
- Open your web browser and access http://<ALB_DNS_NAME>.

Congratulations! You've successfully built a Jenkins-driven CI/CD pipeline that integrates Docker, AWS ECR, and AWS EKS for automated deployments.

Step 6 : Clean Up (Crucial!)
It is absolutely critical to destroy all AWS resources (EKS cluster, RDS if applicable, ALB, etc.) created in previous labs and this lab, as well as Jenkins resources, to avoid incurring significant ongoing costs. To complete Step 6, follow the instructions below : 

- Delete the application from EKS:
- kubectl delete deployment jenkins-deployed-app
  kubectl delete service jenkins-deployed-app-service

This will delete the Deployment, Pods, and the LoadBalancer Service, which in turn will de-provision the AWS Application Load Balancer.
- Delete the Jenkins Pipeline job: Open your web browser to the Jenkins Dashboard.
- Click on Python-Docker-Pipeline.
- In the left navigation, click "Delete Pipeline." Confirm the deletion.

- Remove the webhook from GitHub: 
- Go to your GitHub repository settings -> "Webhooks."
- Find the Jenkins webhook you created and click "Delete."


- Destroy all AWS infrastructure created by Terraform :
- Navigate to your eks-cluster-terraform folder.
- terraform destroy
- Type yes and press Enter to confirm.
- Stop and remove Jenkins agent Docker container (if still running): docker stop jenkins-agent docker rm jenkins-agent

- Stop and remove Jenkins master Docker container and volume (if completely finished):
docker stop jenkins-server docker rm jenkins-server

### Summary
This breakdown provides a step-by-step guide to Deploying a containerized application to Kubernetes on AWS using Jenkins as a CI/CD engine. By completing this lab, we successfully brought together Docker, AWS, Kubernetes, and Jenkins into a unified and fully automated CI/CD pipeline. This workflow demonstrated how Jenkins can orchestrate every stage of cloud-native delivery, from building container images to pushing them to Amazon ECR, configuring access to an EKS cluster, and deploying the application using Kubernetes manifests.

Through this process, we learned how to securely integrate Jenkins with AWS services, manage credentials, automate Docker builds, and trigger deployments to Kubernetes in a consistent and repeatable way. More importantly, this lab reflected a real-world DevOps pattern where automation, containerization, and cloud orchestration come together to enable reliable, scalable, and fast application delivery.
