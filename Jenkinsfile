pipeline {
    agent {
        label 'docker-agent'
    }

    environment {
        // Docker / Image
        DOCKERHUB_USERNAME = 'latefab'
        IMAGE_NAME         = "${DOCKERHUB_USERNAME}/jenkins-docker-app"
        IMAGE_TAG          = "${env.BUILD_NUMBER}"
        LATEST_TAG         = "latest"

        // AWS / ECR
        AWS_REGION     = 'us-east-1'
        AWS_ACCOUNT_ID = '694862618269'
        ECR_REPO_NAME  = 'my-flask-app-repo'
        ECR_REPO_URI   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"

        // EKS
        EKS_CLUSTER_NAME     = 'my-k8s-cluster'
        KUBERNETES_NAMESPACE = 'default'

        // RDS
        RDS_ENDPOINT = 'my-flask-app-db.c1qkikkoozqc.us-east-1.rds.amazonaws.com'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "--- Building Docker Image ---"
                    sh """
                      docker build \
                        -t ${IMAGE_NAME}:${IMAGE_TAG} \
                        -t ${IMAGE_NAME}:${LATEST_TAG} \
                        .
                    """
                }
            }
        }

        stage('Push Docker Image to ECR') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']
                ]) {
                    script {
                        echo "--- Logging in to AWS ECR ---"
                        sh """
                          aws ecr get-login-password --region ${AWS_REGION} \
                          | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                        """

                        echo "--- Tagging Docker Image ---"
                        sh """
                          docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REPO_URI}:${IMAGE_TAG}
                          docker tag ${IMAGE_NAME}:${LATEST_TAG} ${ECR_REPO_URI}:${LATEST_TAG}
                        """

                        echo "--- Pushing Docker Image to ECR ---"
                        sh """
                          docker push ${ECR_REPO_URI}:${IMAGE_TAG}
                          docker push ${ECR_REPO_URI}:${LATEST_TAG}
                        """
                    }
                }
            }
        }

        stage('Deploy to EKS with Helm') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']
                ]) {
                    script {
                        echo "--- Configuring kubectl for EKS ---"
                        sh """
                          aws eks update-kubeconfig \
                            --name ${EKS_CLUSTER_NAME} \
                            --region ${AWS_REGION}

                          kubectl config set-context --current --namespace ${KUBERNETES_NAMESPACE}
                        """

                        echo "--- Deploying Helm Chart ---"
                        dir('my-flask-chart') {
                            sh """
                              helm upgrade my-flask-app-release . \
                                --install \
                                --wait \
                                --timeout 10m \
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
            echo "✅ Build, Push, and Helm Deployment succeeded!"
        }
        failure {
            echo "❌ Pipeline failed. Check logs for details."
        }
    }
}
