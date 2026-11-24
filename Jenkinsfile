pipeline {
    agent any

    environment {
        JAVA_HOME = '/usr/lib/jvm/java-17-openjdk-amd64'
        PATH = "${JAVA_HOME}/bin:${env.PATH}"
    }

    options {
        timestamps()
    }

    triggers {
        githubPush()
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
                sh '''
                    java -version
                    javac -version
                    mvn --version
                    node --version
                    npm --version
                    docker --version
                    docker compose version
                    kubectl version --client
                '''
            }
        }

        stage('Backend - Build & Tests') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'mysql-db-password',
                        variable: 'DB_PASSWORD'
                    )
                ]) {
                    withEnv(['DB_USERNAME=backend_user']) {
                        dir('backend') {
                            sh '''
                                chmod +x mvnw
                                ./mvnw clean verify
                            '''
                        }
                    }
                }
            }
        }

        stage('Frontend - Install & Build') {
            steps {
                dir('frontend') {
                    sh 'npm ci'
                    sh 'npm run build'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    def scannerHome = tool 'SonarScanner'

                    withSonarQubeEnv('SonarQube') {
                        sh "${scannerHome}/bin/sonar-scanner"
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Archive Artifacts') {
            steps {
                archiveArtifacts(
                    artifacts: 'backend/target/*.jar, frontend/dist/**',
                    fingerprint: true
                )
            }
        }

        stage('Docker - Build Images') {
            steps {
                sh '''
                    set -eu

                    docker build \
                        -t sanou/backend-appgestion:${BUILD_NUMBER} \
                        -t sanou/backend-appgestion:latest \
                        ./backend

                    docker build \
                        -t sanou/frontend-appgestion:${BUILD_NUMBER} \
                        -t sanou/frontend-appgestion:latest \
                        ./frontend
                '''
            }
        }

        stage('Docker Hub - Push Images') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKERHUB_USER',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    sh '''
                        set +x
                        set -e

                        echo "$DOCKERHUB_TOKEN" | docker login \
                            --username "$DOCKERHUB_USER" \
                            --password-stdin

                        docker push sanou/backend-appgestion:${BUILD_NUMBER}
                        docker push sanou/backend-appgestion:latest

                        docker push sanou/frontend-appgestion:${BUILD_NUMBER}
                        docker push sanou/frontend-appgestion:latest

                        docker logout
                    '''
                }
            }
        }

        stage('Deploy - Kubernetes') {
            steps {
                echo 'Deploiement automatique sur Minikube'

                withCredentials([
                    file(
                        credentialsId: 'k8s-kubeconfig',
                        variable: 'KUBECONFIG'
                    ),
                    string(
                        credentialsId: 'mysql-db-password',
                        variable: 'DB_PASSWORD'
                    ),
                    string(
                        credentialsId: 'mysql-root-password',
                        variable: 'MYSQL_ROOT_PASSWORD'
                    )
                ]) {
                    sh '''
                        #!/bin/bash
                        set -euo pipefail
                        set +x

                        echo "1. Creation ou mise a jour du Secret MySQL"

                        kubectl create secret generic mysql-secret \
                            --from-literal=MYSQL_PASSWORD="$DB_PASSWORD" \
                            --from-literal=MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
                            --dry-run=client -o yaml | kubectl apply -f -

                        echo "2. Deploiement du stockage et de MySQL"

                        kubectl apply -f k8s/mysql-pvc.yaml
                        kubectl apply -f k8s/mysql-headless-service.yaml
                        kubectl apply -f k8s/mysql-service.yaml
                        kubectl apply -f k8s/mysql-statefulset.yaml

                        echo "3. Attente du demarrage de MySQL"

                        kubectl rollout status statefulset/mysql \
                            --timeout=300s

                        echo "4. Verification de la base Kubernetes"

                        TABLE_COUNT=$(kubectl exec mysql-0 -- sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -Nse "SHOW TABLES FROM test_db" | wc -l')

                        echo "Nombre de tables dans Kubernetes : $TABLE_COUNT"

                        if [ "$TABLE_COUNT" -eq 0 ]; then
                            echo "Base vide : verification de la base Docker Compose"

                            if [ "$(docker inspect -f '{{.State.Running}}' appgestion-db)" != "true" ]; then
                                echo "ERREUR : le conteneur appgestion-db doit etre demarre pour la migration initiale."
                                exit 1
                            fi

                            echo "Migration initiale des donnees MySQL"

                            docker exec -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" \
                                appgestion-db \
                                mysqldump -uroot --single-transaction \
                                --routines --triggers test_db \
                                | kubectl exec -i mysql-0 -- sh -c \
                                'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot test_db'

                            echo "Migration initiale terminee."
                        else
                            echo "Base deja initialisee : aucune reimportation."
                        fi

                        echo "5. Deploiement du Backend et du Frontend"

                        kubectl apply -f k8s/backend-service.yaml
                        kubectl apply -f k8s/backend-deployment.yaml
                        kubectl apply -f k8s/frontend-service.yaml
                        kubectl apply -f k8s/frontend-deployment.yaml

                        echo "6. Mise a jour des images avec le numero du build"

                        kubectl set image deployment/backend \
                            backend=sanou/backend-appgestion:${BUILD_NUMBER}

                        kubectl set image deployment/frontend \
                            frontend=sanou/frontend-appgestion:${BUILD_NUMBER}

                        echo "7. Verification des deploiements"

                        kubectl rollout status deployment/backend \
                            --timeout=300s

                        kubectl rollout status deployment/frontend \
                            --timeout=300s

                        echo "8. Etat final des ressources"

                        kubectl get pods -o wide
                        kubectl get services
                        kubectl get deployments
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'CI/CD termine avec succes !'
            echo 'Tests Backend et Frontend valides.'
            echo 'Quality Gate SonarQube valide.'
            echo 'Images publiees sur Docker Hub.'
            echo 'Application deployee sur Kubernetes.'
        }

        failure {
            echo 'Echec du pipeline. Consulter les logs Jenkins.'
        }

        always {
            echo 'Execution du pipeline terminee.'
        }
    }
}
