
pipeline {
    agent any

    options {
        timestamps()
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Recuperation du projet'
                checkout scm
            }
        }

        stage('Backend - Build & Tests') {
            steps {
                echo 'Compilation et tests Spring Boot'

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
                    sh 'node --version'
                    sh 'npm --version'
                    sh 'npm ci'
                    sh 'npm run build'
                }
            }
        }

        stage('Archive Artifacts') {
            steps {
                echo 'Archivage des fichiers generes'

                archiveArtifacts artifacts: 'backend/target/*.jar, frontend/dist/**',
                                 fingerprint: true
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
    }
}

