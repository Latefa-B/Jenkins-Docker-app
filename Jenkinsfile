pipeline {
    agent {
        label 'docker-agent'
    }

    environment {
        // Docker
        DOCKERHUB_USERNAME = 'latefab'
        IMAGE_NAME = "${DOCKERHUB_USERNAME}/jenkins-python-app"
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        LATEST_TAG = "latest"

        // AWS / ECR
        ECR_REPO_URI = '694862618269.dkr.ecr.us-east-1.amazonaws.com/my-flask-app-repo'
        AWS_REGION = 'us-east-1'
        AWS_ACCOUNT_ID = '694862618269'

        // EKS
        EKS_CLUSTER_NAME = 'my-k8s-cluster'
        KUBERNETES_NAMESPACE = 'default'

        // RDS
        RDS_ENDPOINT = 'my-flask-app-db.c1qkikkoozqc.us-east-1.rds.amazonaws.com'

        // Terraform
        TERRAFORM_INFRA_REPO = 'https://github.com/Latefa-B/jenkins-terraform-infra.git'
        TERRAFORM_BRANCH = 'latefa-branch'
        TERRAFORM_STATE_BUCKET = "jenkins-terraform-state-${AWS_ACCOUNT_ID}"
        TERRAFORM_STATE_KEY = "s3-bucket-infra/terraform.tfstate"
        TERRAFORM_LOCK_TABLE = "terraform-lock-table"
    }

    stages {
        stage('Checkout Application Code') {
            steps {
                checkout scm
            }
        }

        stage('Checkout Terraform Infra Code') {
            steps {
                dir('jenkins-terraform-infra') {
                    deleteDir()
                    git branch: "${TERRAFORM_BRANCH}", url: "${TERRAFORM_INFRA_REPO}"
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                dir("${env.WORKSPACE}") {
                    sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:${LATEST_TAG} ."
                }
            }
        }

        stage('Push Docker Image to ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO_URI}
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REPO_URI}:${IMAGE_TAG}
                        docker tag ${IMAGE_NAME}:${LATEST_TAG} ${ECR_REPO_URI}:${LATEST_TAG}
                        docker push ${ECR_REPO_URI}:${IMAGE_TAG}
                        docker push ${ECR_REPO_URI}:${LATEST_TAG}
                    """
                }
            }
        }

        stage('Update App Version in Infra') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    dir('jenkins-terraform-infra') {
                        sh 'ls -la' // Debug: verify .tf files exist
                        sh """
                            terraform init \
                                -backend-config="bucket=${TERRAFORM_STATE_BUCKET}" \
                                -backend-config="key=${TERRAFORM_STATE_KEY}" \
                                -backend-config="region=${AWS_REGION}" \
                                -backend-config="encrypt=true" \
                                -backend-config="dynamodb_table=${TERRAFORM_LOCK_TABLE}"
                        """
                        sh "terraform plan -out=tfplan.out -var='aws_region=${AWS_REGION}' -var='app_version_content=${IMAGE_TAG}'"
                        sh "terraform apply -auto-approve tfplan.out"
                    }
                }
            }
        }

        stage('Deploy to EKS with Helm') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', cr]()]()
