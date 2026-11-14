
pipeline {
    agent any

    environment {
        JAVA_HOME = '/usr/lib/jvm/java-17-openjdk-amd64'
        PATH = "${JAVA_HOME}/bin:${env.PATH}"
    }

    options {
        timestamps()
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
                echo 'Installation des dependances et compilation Angular'

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
    }

    post {
        success {
            echo 'Pipeline execute avec succes !'
        }

        failure {
            echo 'Echec du pipeline. Consulter les logs.'
        }

        always {
            echo 'Execution du pipeline terminee.'
        }
    }
}

