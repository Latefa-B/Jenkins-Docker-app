pipeline {
    agent any

    environment {
        DOCKERHUB_USERNAME = 'latefab'
        IMAGE_NAME = "${DOCKERHUB_USERNAME}/jenkins-docker-app"
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        LATEST_TAG = "latest"
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
                    sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:${LATEST_TAG} ."
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                    script {
                        echo "--- Logging in to Docker Hub ---"
                        sh "echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin"

                        echo "--- Pushing Docker Image ---"
                        sh "docker push ${IMAGE_NAME}:${IMAGE_TAG}"
                        sh "docker push ${IMAGE_NAME}:${LATEST_TAG}"
                    }
                }
            }
        }

        stage('Test Application (Run Container)') {
            steps {
                script {
                    echo "--- Running Docker Container for Test ---"
                    sh """
                    docker run -d --name test-app -p 5001:5000 ${IMAGE_NAME}:${LATEST_TAG}
                    sleep 3
                    docker logs test-app
                    docker stop test-app
                    docker rm test-app
                    """
                }
            }
        }
    }

    post {
        always {
            echo "Pipeline finished. Status: ${currentBuild.result}"
        }
        success {
            echo "Congratulations! Build succeeded."
        }
        failure {
            echo "Build failed. Please check logs."
        }
    }
}

