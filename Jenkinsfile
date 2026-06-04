pipeline {

    agent any

    environment {
        AWS_ACCESS_KEY = credentials('AWS_ACCESS_KEY')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_DEFAULT_REGION = "us-east-1"
        CLUSTER_NAME = "landmark-eks-cluster"
        DOCKER_REPO = "landmark/devopsapp"
        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {
        stage('Git Checkout') {
            steps {
                echo 'Cloning project codebase...'
                git branch: 'main', url: 'https://github.com/LandmakTechnology/devopsapp.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh "docker build -t ${DOCKER_REPO}:${IMAGE_TAG} ."
                    sh "docker tag ${DOCKER_REPO}:${IMAGE_TAG} ${DOCKER_REPO}:latest"
                    sh 'docker images'
                }
            }
        }

        stage('Docker Login & Push') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'DOCKER', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                        sh 'echo $DOCKER_PASSWORD | docker login -u $DOCKER_USERNAME --password-stdin'
                        sh "docker push ${DOCKER_REPO}:${IMAGE_TAG}"
                        sh "docker push ${DOCKER_REPO}:latest"
                    }
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                script {
                    sh "aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_DEFAULT_REGION}"
                    sh "sed -i 's|chafah/devopsapp:latest|${DOCKER_REPO}:${IMAGE_TAG}|g' kubernetes/03-deployment/deployment.yaml"
                    sh "kubectl apply -f kubernetes/01-namespace/namespace.yaml"
                    sh "kubectl apply -f kubernetes/04-configmap/configmap.yaml"
                    sh "kubectl apply -f kubernetes/03-deployment/deployment.yaml"
                    sh "kubectl apply -f kubernetes/03-deployment/service.yaml"
                    sh "kubectl get svc -n landmark"
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully! Application deployed to EKS.'
        }
        failure {
            echo 'Pipeline failed. Check the logs for details.'
        }
    }
}
