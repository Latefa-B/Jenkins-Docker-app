pipeline {
    agent {
        label 'docker-agent' // Must have Docker, AWS CLI, Kubectl, Helm, Terraform
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

        // Terraform Infra
        TERRAFORM_INFRA_REPO = 'https://github.com/Latefa-B/jenkins-terraform-infra.git'
        TERRAFORM_BRANCH = 'latefa-branch'   // ✅ Correct branch
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
                    deleteDir()  // clean folder before clone
                    git branch: "${TERRAFORM_BRANCH}", url: "${TERRAFORM_INFRA_REPO}", changelog: false, poll: false
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                dir("${env.WORKSPACE}") {
                    script {
                        echo "--- Building Docker Image: ${IMAGE_NAME}:${IMAGE_TAG} ---"
                        sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:${LATEST_TAG} ."
                    }
                }
            }
        }

        stage('Push Docker Image to ECR') {
            steps {
                withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                    script {
                        echo "--- Logging in to AWS ECR ---"
                        sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO_URI}"

                        echo "--- Tagging image for ECR ---"
                        sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REPO_URI}:${IMAGE_TAG}"
                        sh "docker tag ${IMAGE_NAME}:${LATEST_TAG} ${ECR_REPO_URI}:${LATEST_TAG}"

                        echo "--- Pushing Docker Image to ECR ---"
                        sh "docker push ${ECR_REPO_URI}:${IMAGE_TAG}"
                        sh "docker push ${ECR_REPO_URI}:${LATEST_TAG}"
                    }
                }
            }
        }

        stage('Update App Version in Infra') {
            steps {
                withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                    dir('jenkins-terraform-infra') {
                        // ✅ Debug: verify Terraform files exist
                        sh 'ls -la'

                        echo "--- Terraform Init ---"
                        sh """
                            terraform init \
                                -backend-config="bucket=${TERRAFORM_STATE_BUCKET}" \
                                -backend-config="key=${TERRAFORM_STATE_KEY}" \
                                -backend-config="region=${AWS_REGION}" \
                                -backend-config="encrypt=true" \
                                -backend-config="dynamodb_table=${TERRAFORM_LOCK_TABLE}"
                        """

                        echo "--- Terraform Plan ---"
                        sh """
                            terraform plan -out=tfplan.out \
                                -var="aws_region=${AWS_REGION}" \
                                -var="app_version_content=${IMAGE_TAG}"
                        """

                        echo "--- Terraform Apply ---"
                        sh "terraform apply -auto-approve tfplan.out"
                    }
                }
            }
        }

        stage('Deploy to EKS with Helm') {
            steps {
                withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                    dir("${env.WORKSPACE}") {
                        echo "--- Configuring kubectl for EKS ---"
                        sh "aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}"
                        sh "kubectl config use-context arn:aws:eks:${AWS_REGION}:${AWS_ACCOUNT_ID}:cluster/${EKS_CLUSTER_NAME}"
                        sh "kubectl config set-context --current --namespace ${KUBERNETES_NAMESPACE}"

                        echo "--- Deploying Helm Chart ---"
                        dir('my-flask-chart') {
                            sh """
                                helm upgrade my-flask-app-release . --install --atomic --wait --timeout 5m \
                                  --set image.repository=${ECR_REPO_URI} \
                                  --set image.tag=${IMAGE_TAG} \
                                  --set service.type=LoadBalancer \
                                  --set service.port=80 \
                                  --set service.targetPort=5000 \
                                  --set env.DB_HOST=${RDS_ENDPOINT} \
                                  --set env.DB_NAME=mydatabase \
                                  --set env.DB_USER=myuser \
                                  --set env.DB_PASSWORD=mypassword \
                                  --set replicaCount=2
                            """
                        }
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
            echo "🎉 Full Stack Deployment succeeded!"
        }
        failure {
            echo "❌ Full Stack Deployment failed. Check logs!"
        }
    }
}
