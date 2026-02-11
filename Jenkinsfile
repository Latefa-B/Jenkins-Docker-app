pipeline {
    agent {
        label 'docker-agent' // Ensure this runs on your agent with Docker, AWS CLI, Kubectl, Helm, Terraform
    }

    environment {
        // Replace YOUR_DOCKERHUB_USERNAME with your actual Docker Hub username (for image name consistency)
        DOCKERHUB_USERNAME = 'latefab'
        IMAGE_NAME = "${DOCKERHUB_USERNAME}/jenkins-python-app" // This is the local image name

        IMAGE_TAG = "${env.BUILD_NUMBER}"
        LATEST_TAG = "latest"

        // AWS ECR repository URI (replace YOUR_AWS_ACCOUNT_ID and YOUR_AWS_REGION)
        ECR_REPO_URI = '694862618269.dkr.ecr.YOUR_AWS_REGION.amazonaws.com/my-flask-app-repo' // From Lab 6
        AWS_REGION = 'us-east-1' // e.g., us-east-1
        AWS_ACCOUNT_ID = '694862618269' // Your AWS Account ID

        // EKS Cluster details (replace YOUR_EKS_CLUSTER_NAME)
        EKS_CLUSTER_NAME = 'my-k8s-cluster' // From Lab 14
        KUBERNETES_NAMESPACE = 'default' // Or your target namespace

        // RDS Database Endpoint (replace YOUR_RDS_ENDPOINT from Lab 15)
        RDS_ENDPOINT = 'my-flask-app-db.c1qkikkoozqc.us-east-1.rds.amazonaws.com' // e.g., my-flask-app-db.abcdef123456.us-east-1.rds.amazonaws.com

        // Terraform Infra Repo details (replace YOUR_GITHUB_USERNAME and YOUR_TERRAFORM_REPO_NAME)
        TERRAFORM_INFRA_REPO = 'https://github.com/Latefa-B/jenkins-terraform-infra.git'
        TERRAFORM_STATE_BUCKET = "jenkins-terraform-state-${AWS_ACCOUNT_ID}"
        TERRAFORM_STATE_KEY = "s3-bucket-infra/terraform.tfstate"
        TERRAFORM_LOCK_TABLE = "terraform-lock-table"

        // App Version S3 Bucket (from Terraform infra)
        APP_VERSION_S3_BUCKET = "app-version-bucket-${AWS_ACCOUNT_ID}"
        APP_VERSION_FILE_KEY = "current-app-version.txt"
    }

    stages {
        stage('Checkout Application Code') {
            steps {
                // Checkout the primary application repository
                checkout scm
            }
        }

        stage('Checkout Terraform Infra Code') {
            steps {
                // Checkout the Terraform infrastructure repository into a sub-directory
                git branch: 'main', url: "${TERRAFORM_INFRA_REPO}", changelog: false, poll: false
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "--- Building Docker Image: ${IMAGE_NAME}:${IMAGE_TAG} ---"
                    // Build from the jenkins-git-app folder (current workspace root)
                    sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:${LATEST_TAG} ."
                }
            }
        }

        stage('Push Docker Image to ECR') {
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials', variable: 'AWS_CREDS')]) {
                    script {
                        echo "--- Logging in to AWS ECR ---"
                        sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO_URI}"

                        echo "--- Tagging image for ECR ---"
                        sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REPO_URI}:${IMAGE_TAG}"
                        sh "docker tag ${IMAGE_NAME}:${LATEST_TAG} ${ECR_REPO_URI}:${LATEST_TAG}"

                        echo "--- Pushing Docker Image to ECR ---"
                        sh "docker push ${ECR_REPO_URI}:${IMAGE_TAG}"
                        sh "docker push ${ECR_REPO_URI}:${LATEST_TAG}"

                        echo "--- Docker Image Push to ECR Complete ---"
                    }
                }
            }
        }

        stage('Update App Version in Infra') {
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials', variable: 'AWS_CREDS')]) {
                    script {
                        echo "--- Updating App Version in Infrastructure (Terraform) ---"
                        // Navigate to the Terraform infra directory
                        dir('jenkins-terraform-infra-repo') { // This is the folder name after git checkout
                            sh "pwd" // Verify current directory
                            echo "--- Terraform Init for App Version Infra ---"
                            sh "terraform init -backend-config=\"bucket=${TERRAFORM_STATE_BUCKET}\" -backend-config=\"key=${TERRAFORM_STATE_KEY}\" -backend-config=\"region=${AWS_REGION}\" -backend-config=\"encrypt=true\" -backend-config=\"dynamodb_table=${TERRAFORM_LOCK_TABLE}\""

                            echo "--- Terraform Plan for App Version Infra ---"
                            // Pass the current build number as the app version content
                            sh "terraform plan -out=tfplan.out -var=\"aws_region=${AWS_REGION}\" -var=\"app_version_content=${IMAGE_TAG}\""

                            echo "--- Terraform Apply for App Version Infra ---"
                            sh "terraform apply -auto-approve tfplan.out"
                        }
                        echo "--- App Version Infra Update Complete ---"
                    }
                }
            }
        }

        stage('Deploy to EKS with Helm') {
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials', variable: 'AWS_CREDS')]) {
                    script {
                        echo "--- Configuring kubectl for EKS ---"
                        sh "aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}"
                        sh "kubectl config use-context arn:aws:eks:${AWS_REGION}:${AWS_ACCOUNT_ID}:cluster/${EKS_CLUSTER_NAME}"
                        sh "kubectl config set-context --current --namespace ${KUBERNETES_NAMESPACE}"

                        echo "--- Deploying Helm Chart to EKS ---"
                        // Navigate to the Helm chart directory relative to the workspace root
                        dir('my-flask-chart') { // Change directory into the Helm chart folder
                            sh "helm upgrade my-flask-app-release . --install --atomic --wait --timeout 5m " +
                               "--set image.repository=${ECR_REPO_URI} " +
                               "--set image.tag=${IMAGE_TAG} " +
                               "--set service.type=LoadBalancer " +
                               "--set service.port=80 " +
                               "--set service.targetPort=5000 " +
                               "--set env.DB_HOST=${RDS_ENDPOINT} " +
                               "--set env.DB_NAME=mydatabase " +
                               "--set env.DB_USER=myuser " +
                               "--set env.DB_PASSWORD=mypassword " +
                               "--set replicaCount=2"
                        }
                        echo "--- Helm Deployment to EKS Complete ---"
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Pipeline finished. Status: ${currentBuild.result}"
        }
        success {
            echo "Congratulations! Full Stack Deployment succeeded."
        }
        failure {
            echo "Full Stack Deployment failed. Please check logs."
        }
    }
}
