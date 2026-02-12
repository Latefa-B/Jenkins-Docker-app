pipeline {
    agent { label 'docker-agent' }

    environment {
        AWS_REGION = 'us-east-1'                      // Set your AWS region
        ECR_REPO_URI = '694862618269.dkr.ecr.us-east-1.amazonaws.com/my-flask-app-repo' // Replace with your ECR URI
        AWS_ACCOUNT_ID = "694862618269" // Your AWS Account ID
        DOCKERHUB_USERNAME = 'latefab'
        IMAGE_NAME = "${DOCKERHUB_USERNAME}/jenkins-python-app" // This is the local image name
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        LATEST_TAG = "latest"
        EKS_CLUSTER_NAME = 'my-k8s-cluster' // From Lab 14
        KUBERNETES_NAMESPACE = 'default' // Or your target namespace
        RDS_ENDPOINT = 'my-flask-app-db.c1qkikkoozqc.us-east-1.rds.amazonaws.com' // e.g., my-flask-app-db.abcdef123456.us-east-1.rds.amazonaws.com
        TERRAFORM_INFRA_REPO = 'https://github.com/Latefa-B/jenkins-terraform-infra.git'
        TERRAFORM_STATE_BUCKET = 'jenkins-terraform-state-694862618269' // Replace with your bucket
        TERRAFORM_STATE_KEY = "s3-bucket-infra/terraform.tfstate"
        TERRAFORM_LOCK_TABLE = "terraform-lock-table"
        HELM_RELEASE_NAME = 'my-flask-app-release'
        HELM_NAMESPACE = 'default'
        KUBE_CONFIG = '/home/jenkins/.kube/config'
        APP_VERSION_S3_BUCKET = "app-version-bucket-${AWS_ACCOUNT_ID}"
        APP_VERSION_FILE_KEY = "current-app-version.txt"
    }



    stages {

        stage('Checkout SCM') {
            steps {
                git branch: 'latefa-branch', url: 'https://github.com/Latefa-B/jenkins-docker-app.git'
            }
        }

        stage('Checkout Application Code') {
            steps {
                dir('app') {
                    git branch: 'latefa-branch', url: 'https://github.com/Latefa-B/jenkins-docker-app.git'
                }
            }
        }

        stage('Checkout Terraform Infra Code') {
            steps {
                dir('jenkins-terraform-infra') {
                    deleteDir()
                    git branch: 'latefa-branch', url: 'https://github.com/Latefa-B/jenkins-terraform-infra.git'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                dir('app') {
                    script {
                        echo "--- Building Docker Image: ${ECR_REPO_URI}:${IMAGE_TAG} ---"
                        sh """
                            docker build -t ${ECR_REPO_URI}:${IMAGE_TAG} -t ${ECR_REPO_URI}:latest .
                        """
                    }
                }
            }
        }

        stage('Push Docker Image to ECR') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    script {
                        sh """
                            # Configure AWS CLI
                            aws configure set aws_access_key_id \$AWS_ACCESS_KEY_ID
                            aws configure set aws_secret_access_key \$AWS_SECRET_ACCESS_KEY
                            aws configure set default.region ${AWS_REGION}

                            # Login to ECR
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO_URI}

                            # Push images
                            docker push ${ECR_REPO_URI}:${IMAGE_TAG}
                            docker push ${ECR_REPO_URI}:latest
                        """
                    }
                }
            }
        }

        stage('Update App Version in Infra') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    dir('jenkins-terraform-infra') {
                        script {
                            sh """
                                # Configure AWS CLI
                                aws configure set aws_access_key_id \$AWS_ACCESS_KEY_ID
                                aws configure set aws_secret_access_key \$AWS_SECRET_ACCESS_KEY
                                aws configure set default.region ${AWS_REGION}

                                # Terraform init & apply
                                terraform init -backend-config="bucket=${TERRAFORM_STATE_BUCKET}" \
                                               -backend-config="key=${TERRAFORM_STATE_KEY}" \
                                               -backend-config="region=${AWS_REGION}" \
                                               -backend-config="encrypt=true" \
                                               -backend-config="dynamodb_table=${TERRAFORM_LOCK_TABLE}"
                                terraform apply -auto-approve -var="app_version_content=${IMAGE_TAG}"
                            """
                        }
                    }
                }
            }
        }
        stage('Configure Kubeconfig') {
           steps {
               withCredentials([[
                   $class: 'AmazonWebServicesCredentialsBinding',
                   credentialsId: 'aws-credentials'
               ]]) {
                   script {
                       sh """
                           aws configure set aws_access_key_id \$AWS_ACCESS_KEY_ID
                           aws configure set aws_secret_access_key \$AWS_SECRET_ACCESS_KEY
                           aws configure set default.region ${AWS_REGION}

                           aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION} --kubeconfig ${KUBE_CONFIG}
                       """
                   }
               }
           }
       }

        stage('Deploy to EKS with Helm') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    script {
                        sh """
                            # Configure AWS CLI
                            aws configure set aws_access_key_id \$AWS_ACCESS_KEY_ID
                            aws configure set aws_secret_access_key \$AWS_SECRET_ACCESS_KEY
                            aws configure set default.region ${AWS_REGION}

                            # Helm deploy
                            helm upgrade --install ${HELM_RELEASE_NAME} ./my-flask-chart \
                                --namespace ${HELM_NAMESPACE} \
                                --set image.repository=${ECR_REPO_URI} \
                                --set image.tag=${IMAGE_TAG} \
                                --kubeconfig ${KUBE_CONFIG}
                        """
                    }
                }
            }
        }

    }

    post {
        success {
            echo "✅ Full Stack Deployment completed successfully!"
        }
        failure {
            echo "❌ Full Stack Deployment failed. Check logs!"
        }
    }
}
