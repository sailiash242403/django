pipeline {
    agent none

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        DOCKERHUB_USER = 'thatavarthi403'
        IMAGE_NAME     = 'django-app'
        DOCKERHUB_PASS = credentials('dockerhub-creds')
        SONARQUBE_ENV  = 'sonarqube-server'
    }

    stages {

        stage('Checkout Code') {
            agent { label 'built-in' }
            steps {
                checkout scm
                stash name: 'source_code', includes: '**/*'
            }
        }

        stage('Pylint Analysis') {
            agent { label 'jenkins-build-node' }
            steps {
                unstash 'source_code'
                sh '''
                    set -e
                    python3 -m venv .venv_pylint
                    . .venv_pylint/bin/activate
                    pip install --upgrade pip
                    pip install pylint
                    pylint --output-format=text $(find . -name "*.py" | grep -v ".venv_pylint" || true) > pylint.log || true
                '''
                recordIssues tools: [pylint(pattern: 'pylint.log')], stable: true
                archiveArtifacts artifacts: 'pylint.log', allowEmptyArchive: true
            }
        }

        stage('Unit Tests + Coverage') {
            agent { label 'jenkins-build-node' }
            steps {
                unstash 'source_code'
                sh '''
                    set -e
                    python3 -m venv .venv_test
                    . .venv_test/bin/activate
                    pip install --upgrade pip
                    pip install -r requirements.txt
                    pip install pytest pytest-cov pytest-django
                    pytest --junitxml=reports/junit.xml --cov=. --cov-report=xml --cov-report=term || true
                '''
                junit 'reports/junit.xml'
                cobertura coberturaReportFile: 'coverage.xml'
                stash name: 'test_artifacts', includes: 'coverage.xml, reports/**', allowEmpty: true
            }
        }

          stage('SonarQube Analysis') {
            agent { label 'built-in' }
            environment {
                SONAR_HOST_URL = credentials('sonar-host-url')
                SONAR_TOKEN    = credentials('sonar-token')
            }
            steps {
                unstash 'source_code'
                unstash 'test_artifacts'
                withSonarQubeEnv('sonarqube-server') {
                    sh """
                        sonar-scanner \
                          -Dsonar.projectKey=django-app \
                          -Dsonar.sources=. \
                          -Dsonar.python.coverage.reportPaths=coverage.xml
                    """
                }
            }
        }

        stage('Docker Build & Push') {
            agent { label 'jenkins-build-node' }
            steps {
                unstash 'source_code'
                sh '''
                    echo "$DOCKERHUB_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin
                    docker build -t ${IMAGE_NAME}:latest .
                    docker tag ${IMAGE_NAME}:latest ${DOCKERHUB_USER}/${IMAGE_NAME}:latest
                    docker push ${DOCKERHUB_USER}/${IMAGE_NAME}:latest
                '''
            }
        }

        stage('Deploy') {
            agent { label 'jenkins-deploy-node' }
            steps {
                sh '''
                    docker pull ${DOCKERHUB_USER}/${IMAGE_NAME}:latest
                    docker stop ${IMAGE_NAME} || true
                    docker rm ${IMAGE_NAME} || true
                    docker run -d -p 5000:5000 --name ${IMAGE_NAME} ${DOCKERHUB_USER}/${IMAGE_NAME}:latest
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: '**/*.log, coverage.xml, reports/**', allowEmptyArchive: true
            cleanWs()
        }
        success {
            echo "✅ Pipeline SUCCESS."
        }
        failure {
            echo "❌ Pipeline FAILED — check logs."
        }
    }
}
