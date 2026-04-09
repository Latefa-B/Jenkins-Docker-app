# Step-by-Step Guide to Deploy a Dockerized Application to ECR and EKS using Jenkins CI/CD pipeline.
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
<img width="587" height="61" alt="54" src="https://github.com/user-attachments/assets/d99ce41f-e87b-4a6d-b0f5-1fa3cb21b072" />

- Create a new folder jenkins-custom-agent using the command line : mkdir jenkins-custom-agent && cd jenkins-custom-agent
Note : The jenkins/ssh-agent:lts image is quite minimal. You'll need to create a custom Dockerfile for your agent or install these tools inside the running agent. 
- Create a custom agent image: Inside, create a Dockerfile and paste the content below.
<img width="804" height="343" alt="1" src="https://github.com/user-attachments/assets/da6a6342-a54f-4217-83d2-d77094aa6a8e" />

- Build this image using the command : docker build -t jenkins-aws-k8s-agent .
<img width="1466" height="835" alt="2" src="https://github.com/user-attachments/assets/787f7a4e-6db7-439b-8e1b-af9be4ffb546" />
<img width="1022" height="888" alt="3" src="https://github.com/user-attachments/assets/fc3bb448-c7ae-465f-a36a-857fcf77d437" />
<img width="990" height="882" alt="4" src="https://github.com/user-attachments/assets/f1d85453-aa7a-4230-84b0-853e8af2bfa0" />
<img width="1457" height="884" alt="5" src="https://github.com/user-attachments/assets/2232e7de-c16f-4e99-8c3f-f760a17b3ed6" />

**Error** : failed to build: failed to solve: process "/bin/sh -c apt-get update && apt-get install -y curl unzip python3 python3-pip && pip3 install awscli && apt-get clean && rm -rf /var/lib/apt/list s/*" did not complete successfully: exit code: 1.

**Explanation** : the Dockerfile build failed due to Linux distro rules . AWS CLI installation could be incompatible with python / pip. 

**Solution** : As an alternative, we have changed to Debian-based images that are more compatible with AWS CLI installation. 

**Troubleshooting steps** : 
**Step 1** : Replace the Dockerfile to a Debian based image instead of python / pip.
<img width="842" height="420" alt="6" src="https://github.com/user-attachments/assets/15554a04-0f1b-443f-8965-38ab636c73cf" />

**Step 2** : Build the dockerfile using the command line : docker build -t jenkins-aws-k8s-agent .
<img width="1393" height="281" alt="7" src="https://github.com/user-attachments/assets/584b1691-64e6-42a2-901e-d2a0577b5050" />

- Run the custom agent using the command line : docker run -d --name jenkins-agent --init -v /var/run/docker.sock:/var/run/docker.sock jenkins-aws-k8s-agent
<img width="675" height="117" alt="8" src="https://github.com/user-attachments/assets/bfaa13b4-2496-4517-8ce7-1f6cd6b30388" />


- Verify Agent Connection: Ensure your docker-agent node in Jenkins (http://localhost:8080/computer/docker-agent/) is "Online." If not, re-run the docker exec -d jenkins-agent java -jar ...
<img width="1439" height="454" alt="9" src="https://github.com/user-attachments/assets/f8191d2a-fcc4-4aca-9c3c-cf452836b377" />
<img width="1453" height="511" alt="10" src="https://github.com/user-attachments/assets/a6fa7430-13c2-4996-b94b-c15df4215283" />


### Step 2: Create Jenkins Credentials for AWS Access
Jenkins needs your AWS Access Key ID and Secret Access Key to interact with AWS services like ECR and EKS. We'll store these securely in Jenkins's Credentials Manager. To complete Step 2, follow the instructions below : 
- Open your web browser and go to your Jenkins Dashboard (http://localhost:8080).
- In the left navigation, click "Manage Jenkins."
- Click "Plugins."
<img width="1462" height="742" alt="11" src="https://github.com/user-attachments/assets/4f4ab91c-9b4e-4b01-81d2-cb73bebdcf9a" />

- Check "Available plugins." and look for AWS Credentials.
<img width="1453" height="384" alt="12" src="https://github.com/user-attachments/assets/b6d98887-9861-48de-8903-d58cc5dabed8" />

- Check “Installed plugins” and make sure the plugin is installed.
<img width="1453" height="331" alt="13" src="https://github.com/user-attachments/assets/d7883366-882c-4661-bbfa-102de442421f" />

- In the left navigation, click "Manage Jenkins."
- Click "Credentials."
<img width="1455" height="745" alt="14" src="https://github.com/user-attachments/assets/85e8ae81-ac90-4cf6-b3d0-adf96a313bb6" />

- In the left navigation, click "System."
<img width="1440" height="347" alt="15" src="https://github.com/user-attachments/assets/734ce6b3-b72f-491c-9fb7-357ab3df3be2" />

- Click "Global credentials (unrestricted)."
<img width="1439" height="193" alt="16" src="https://github.com/user-attachments/assets/8416297a-afe2-47ef-ad90-701105f1d1ac" />

- Click "Add Credentials."
<img width="1448" height="256" alt="17" src="https://github.com/user-attachments/assets/699902be-c3cb-4d24-a4c2-1a5fd8c17d05" />

- Fill in the details:
* Kind: "AWS Credentials" (You might need to install the "AWS Credentials plugin" if this option isn't available. Go to Manage Jenkins -> Plugins -> Available plugins, search for "AWS Credentials plugin").
* Scope: "Global"
* ID: aws-credentials (This is the ID you'll reference in your Jenkins job).
* Access Key ID: Your AWS Access Key ID.
* Secret Access Key: Your AWS Secret Access Key.
* Description: AWS credentials for ECR and EKS access
<img width="1434" height="825" alt="18" src="https://github.com/user-attachments/assets/ceb73701-def3-40b5-93e0-fc5a3c676de8" />

- Click "Create."
<img width="1433" height="320" alt="19" src="https://github.com/user-attachments/assets/490141b7-42bd-4fae-bc62-8b317285e8fa" />


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
<img width="905" height="886" alt="20" src="https://github.com/user-attachments/assets/3753bf88-6ec4-4707-88cc-a17c21a9e461" />
<img width="954" height="889" alt="21" src="https://github.com/user-attachments/assets/cab91280-d541-4971-a526-845f560e4ef1" />
<img width="813" height="423" alt="22" src="https://github.com/user-attachments/assets/82bcfa62-b0e5-48c0-adc0-a254e0c36948" />

- Commit and push the updated Jenkinsfile to your GitHub repository:
cd jenkins-git-app 
git add Jenkinsfile 
git commit -m "Add or Update Jenkinsfile for ECR and EKS deployment" 
git push origin <your-branch-name>
<img width="786" height="253" alt="24" src="https://github.com/user-attachments/assets/d7e1cfe1-e9ba-4f63-86b9-1ae183818940" />


### Step 4: Configure Jenkins Pipeline Job
We'll reuse the Python-Docker-Pipeline job from Lab 3, but ensure it's configured to use our aws-credentials for AWS access. To complete Step 3, follow the instructions below : 
- Open your web browser and go to your Jenkins Dashboard (http://localhost:8080).
- Click on Python-Docker-Pipeline.
- In the left navigation, click "Configure."
<img width="1425" height="771" alt="25" src="https://github.com/user-attachments/assets/7714f50b-7487-4e14-8a81-72b9f3338d51" />

- Ensure "Build Triggers" -> "GitHub hook trigger for GITScm polling" is checked.
<img width="1427" height="759" alt="26" src="https://github.com/user-attachments/assets/08a6d3aa-59eb-4f8a-9519-bc4b6c0a5473" />

- Ensure "Pipeline" -> "Definition:" is "Pipeline script from SCM" and points to your Git repository and Jenkinsfile.
- Add "Additional Behaviors" for AWS Credentials (if not automatically picked up by withCredentials):
- Scroll down to "Source Code Management" -> "Git."
- Click "Add" next to "Additional Behaviors."
- Select "Inject build environment variables."
- For "Credentials," select aws-credentials from the dropdown. This ensures the AWS credentials are available as environment variables for aws CLI commands.
<img width="1401" height="764" alt="27" src="https://github.com/user-attachments/assets/3d31566d-8f8a-4220-a0a1-020f6894f107" />

- Click "Save."
<img width="1431" height="487" alt="28" src="https://github.com/user-attachments/assets/f9a4b5b9-cf74-4237-b724-1f2c5e73e3e4" />


### Step 5: Trigger Pipeline and Verify EKS Deployment
Make a small code change and push it. Jenkins will trigger the pipeline, build the Docker image, push it to ECR, and then deploy it to your EKS cluster. To complete Step 5, follow the instructions below : 
- Navigate to your jenkins-git-app folder locally.
- Open app.py and make a tiny, harmless change (e.g., update a comment).
- Commit and push this change to GitHub:
cd jenkins-git-app 
git add app.py 
git commit -m "Trigger full CI/CD pipeline to EKS" 
git push origin <your-branch-name>
<img width="690" height="262" alt="30" src="https://github.com/user-attachments/assets/970c7015-2c56-4912-bf41-591503e05669" />

- Observe in Jenkins: Go to your Jenkins Dashboard (http://localhost:8080).
- Click on Python-Docker-Pipeline. You should see a new build automatically start.
- Click on the build number.
- Click "Stage View." You'll see new stages: Push Docker Image to ECR and Deploy to EKS.
<img width="1427" height="677" alt="31" src="https://github.com/user-attachments/assets/9b7ba951-5572-49eb-9e75-239e229e5763" />
<img width="1422" height="591" alt="32" src="https://github.com/user-attachments/assets/98af4b5e-8e1f-4071-ad08-e76c83ba4ad6" />
<img width="679" height="196" alt="33" src="https://github.com/user-attachments/assets/41f5db7f-4ce8-4777-9789-5e52acd5fab4" />
<img width="628" height="186" alt="34" src="https://github.com/user-attachments/assets/8210b8a0-a03f-44b2-8cc8-a9e36770188c" />
<img width="647" height="191" alt="35" src="https://github.com/user-attachments/assets/9d0ae97b-9289-47dd-a833-d89291a8e31c" />
<img width="610" height="194" alt="36" src="https://github.com/user-attachments/assets/ded606e5-e3fa-4ecc-922f-1424fb979e20" />
<img width="616" height="194" alt="37" src="https://github.com/user-attachments/assets/aa6844da-3992-4a0d-a6f6-b3bfca2a217e" />
<img width="606" height="191" alt="38" src="https://github.com/user-attachments/assets/ddbad68e-4983-4cc2-8813-1636ed7e2ee6" />

- Monitor the console output for each stage. The Deploy to EKS stage should show kubectl commands executing.
<img width="1442" height="588" alt="39" src="https://github.com/user-attachments/assets/a9301f5c-6fe5-499f-a6d3-3ba095c59f1c" />
<img width="1433" height="817" alt="40" src="https://github.com/user-attachments/assets/3209804f-7a7b-4f92-aa0b-fe43ea12aabe" />
<img width="1425" height="823" alt="41" src="https://github.com/user-attachments/assets/2d6bb329-b8ee-43ed-b74d-7a7ec20a80dd" />
<img width="1433" height="841" alt="42" src="https://github.com/user-attachments/assets/c7dfc965-4df2-4f32-9ec7-b0f631ddc2f0" />
<img width="1432" height="821" alt="43" src="https://github.com/user-attachments/assets/d0322f2d-af93-41cb-856d-95b0c4953291" />
<img width="1425" height="817" alt="44" src="https://github.com/user-attachments/assets/43f5ea2d-4310-41ad-a55e-61d04bb55608" />
<img width="1432" height="817" alt="45" src="https://github.com/user-attachments/assets/7f9447c3-a1ba-45a4-9b8e-c5f3258390a7" />
<img width="1421" height="828" alt="46" src="https://github.com/user-attachments/assets/39c66b6f-b8d1-4a69-b45f-7dea304b5037" />

- Verify EKS Deployment: Once the Jenkins build finishes with SUCCESS, open your local terminal.
<img width="1423" height="808" alt="47" src="https://github.com/user-attachments/assets/c03e4fac-7ba9-46c1-9393-4da2d5d8e73f" />

- Ensure your kubectl is configured to connect to your EKS cluster : aws eks update-kubeconfig --name YOUR_EKS_CLUSTER_NAME --region YOUR_AWS_REGION
<img width="795" height="33" alt="48" src="https://github.com/user-attachments/assets/a0328c5b-0ed4-49df-bcfa-993a6328d7d5" />

- Check the deployed resources:
- kubectl get deployment jenkins-deployed-app
- kubectl get service jenkins-deployed-app-service
<img width="1091" height="130" alt="49" src="https://github.com/user-attachments/assets/f5fa1f16-6532-4eb0-b797-1243d29fb3fa" />
<img width="1174" height="72" alt="50" src="https://github.com/user-attachments/assets/176e9e7f-7774-4fbf-ac83-462082d913c7" />

- Get the EXTERNAL-IP (DNS name) of your jenkins-deployed-app-service. It might take a few minutes for the AWS Load Balancer to provision.
- Open your web browser and access http://<ALB_DNS_NAME>.

<img width="1458" height="273" alt="51" src="https://github.com/user-attachments/assets/d72ca9dc-bfa1-487c-ab18-0ab008f5b101" />
Congratulations! You've successfully built a Jenkins-driven CI/CD pipeline that integrates Docker, AWS ECR, and AWS EKS for automated deployments.

### Step 6 : Clean Up (Crucial!)
It is absolutely critical to destroy all AWS resources (EKS cluster, RDS if applicable, ALB, etc.) created in previous labs and this lab, as well as Jenkins resources, to avoid incurring significant ongoing costs. To complete Step 6, follow the instructions below : 

- Delete the application from EKS:
- kubectl delete deployment jenkins-deployed-app
  kubectl delete service jenkins-deployed-app-service
<img width="701" height="99" alt="52" src="https://github.com/user-attachments/assets/baed3fed-8fa3-419d-b7aa-51c13cc94dee" />


This will delete the Deployment, Pods, and the LoadBalancer Service, which in turn will de-provision the AWS Application Load Balancer.
- Delete the Jenkins Pipeline job: Open your web browser to the Jenkins Dashboard.
- Click on Python-Docker-Pipeline.
- In the left navigation, click "Delete Pipeline." Confirm the deletion.
<img width="838" height="421" alt="53" src="https://github.com/user-attachments/assets/7cedb757-4542-4310-a6f6-afcb493669aa" />


- Remove the webhook from GitHub: 
- Go to your GitHub repository settings -> "Webhooks."
- Find the Jenkins webhook you created and click "Delete."
<img width="1258" height="320" alt="56" src="https://github.com/user-attachments/assets/01cb1b4d-de71-467e-b69a-68fcb0c0dfad" />


- Destroy all AWS infrastructure created by Terraform :
- Navigate to your eks-cluster-terraform folder.
- terraform destroy
- Type yes and press Enter to confirm.
<img width="783" height="113" alt="57" src="https://github.com/user-attachments/assets/826aae71-73f4-4ce4-91d4-bccbcf0ca12c" />

- Stop and remove Jenkins agent Docker container (if still running): docker stop jenkins-agent docker rm jenkins-agent
<img width="587" height="61" alt="54" src="https://github.com/user-attachments/assets/f3ac7fe2-abb9-4309-a806-e058992b97e1" />

### Summary
This breakdown provides a step-by-step guide to Deploying a containerized application to Kubernetes on AWS using Jenkins as a CI/CD engine. By completing this lab, we successfully brought together Docker, AWS, Kubernetes, and Jenkins into a unified and fully automated CI/CD pipeline. This workflow demonstrated how Jenkins can orchestrate every stage of cloud-native delivery, from building container images to pushing them to Amazon ECR, configuring access to an EKS cluster, and deploying the application using Kubernetes manifests.

Through this process, we learned how to securely integrate Jenkins with AWS services, manage credentials, automate Docker builds, and trigger deployments to Kubernetes in a consistent and repeatable way. More importantly, this lab reflected a real-world DevOps pattern where automation, containerization, and cloud orchestration come together to enable reliable, scalable, and fast application delivery.
