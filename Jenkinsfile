
pipeline {
    agent any

    environment {
        JAVA_HOME = '/usr/lib/jvm/java-17-openjdk-amd64'
        PATH = "${JAVA_HOME}/bin:${env.PATH}"

        // Conserver le meme projet Docker Compose
        COMPOSE_PROJECT_NAME = 'devops-appgestiondesprojets'
    }

    options {
        timestamps()
    }

    // Vérifier automatiquement les changements sur GitHub
    triggers {
        pollSCM('H/2 * * * *')
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Recuperation du projet depuis GitHub'
                checkout scm
            }
        }

        stage('Verify Environment') {
            steps {
                echo 'Verification des outils installes'
                sh '''
                    java -version
                    javac -version
                    mvn --version
                    node --version
                    npm --version
                    docker --version
                    docker compose version
                '''
            }
        }

        stage('Backend - Build & Tests') {
            steps {
                echo 'Compilation et execution des tests Spring Boot'

                dir('backend') {
                    sh 'chmod +x mvnw'
                    sh './mvnw clean verify'
                }
            }
        }

        stage('Frontend - Install & Build') {
            steps {
                echo 'Installation et compilation Angular'

                dir('frontend') {
                    sh 'npm ci'
                    sh 'npm run build'
                }
            }
        }

        stage('Archive Artifacts') {
            steps {
                echo 'Archivage des fichiers generes'

                archiveArtifacts(
                    artifacts: 'backend/target/*.jar, frontend/dist/**',
                    fingerprint: true
                )
            }
        }

        stage('Docker - Build Images') {
            steps {
                echo 'Construction des images Docker'

                sh '''
                    docker compose build
                '''
            }
        }

        stage('Docker Hub - Push Images') {
            steps {
                echo 'Publication des images sur Docker Hub'

                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKERHUB_USER',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    sh '''
                        set +x

                        echo "$DOCKERHUB_TOKEN" | docker login \
                            -u "$DOCKERHUB_USER" \
                            --password-stdin

                        docker compose push

                        docker logout
                    '''
                }
            }
        }

        stage('Deploy - Docker Compose') {
            steps {
                echo 'Deploiement automatique de l application'

                sh '''
                    docker compose pull
                    docker compose up -d --remove-orphans
                    docker compose ps
                '''
            }
        }
    }

    post {
        success {
            echo 'CI/CD termine avec succes !'
            echo 'Images publiees sur Docker Hub.'
            echo 'Application deployee avec Docker Compose.'
        }

        failure {
            echo 'Echec du pipeline. Consulter les logs Jenkins.'
        }

        always {
            echo 'Execution du pipeline terminee.'
        }
    }
}

