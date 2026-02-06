pipeline {
    agent {
        label 'docker-agent' // Must match the agent label from Lab 4
    }

    environment {
        // Local image name used before tagging for ECR
        DOCKERHUB_USERNAME = 'latefab'
        IMAGE_NAME = "${DOCKERHUB_USERNAME}/jenkins-docker-app"
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        LATEST_TAG = "latest"

        // AWS / ECR / EKS configuration
        AWS_REGION     = 'us-east-1'          // e.g. us-east-1
        AWS_ACCOUNT_ID = '694862618269'      // e.g. 123456789012
        ECR_REPO_NAME  = 'my-flask-app-repo'        // existing ECR repo
        ECR_REPO_URI   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"

        EKS_CLUSTER_NAME      = 'my-k8s-cluster'    // your EKS cluster name
        KUBERNETES_NAMESPACE  = 'default'
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
                    echo "--- Building Docker Image: ${IMAGE_NAME}:${IMAGE_TAG} ---"
                    sh """
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:${LATEST_TAG} .
                    """
                }
            }
        }

        stage('Push Docker Image to ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    script {
                        echo "--- Logging in to AWS ECR ---"
                        sh """
                        aws ecr get-login-password --region ${AWS_REGION} \
                          | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                        """

                        echo "--- Tagging image for ECR ---"
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

        stage('Deploy to EKS') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    script {
                        echo "--- Configuring kubectl for EKS ---"
                        sh """
                        aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}
                        kubectl config set-context --current --namespace ${KUBERNETES_NAMESPACE}
                        """

                        echo "--- Applying Kubernetes manifests ---"

                        def k8sManifest = """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins-deployed-app
  labels:
    app: jenkins-deployed-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins-deployed-app
  template:
    metadata:
      labels:
        app: jenkins-deployed-app
    spec:
      containers:
      - name: flask-app
        image: ${ECR_REPO_URI}:${IMAGE_TAG}
        ports:
        - containerPort: 5000
---
apiVersion: v1
kind: Service
metadata:
  name: jenkins-deployed-app-service
  labels:
    app: jenkins-deployed-app
spec:
  type: LoadBalancer
  selector:
    app: jenkins-deployed-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5000
"""

                        // Apply the manifest
                        sh """
                        echo "${k8sManifest}" | kubectl apply -f -
                        """

                        echo "--- Waiting for Deployment to be ready ---"
                        sh """
                        kubectl rollout status deployment/jenkins-deployed-app --timeout=300s
                        """
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
            echo "Congratulations! Build and deployment to EKS succeeded."
        }
        failure {
            echo "Build or deployment failed. Please check the logs."
        }
    }
}

