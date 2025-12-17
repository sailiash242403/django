pipeline {
    agent none

    options {
        skipDefaultCheckout(true)
    }

    environment {
        DOCKERHUB_USER = 'thatavarthi403'
        IMAGE_NAME     = 'django-app'
        DOCKERHUB_PASS = credentials('dockerhub-creds')
    }

    stages {

        stage('Checkout Code') {
            agent { label 'built-in' }
            steps {
                checkout scm
                stash includes: '**', name: 'source-code'
            }
        }

        stage('SonarQube Scan') {
            agent { label 'built-in' }
            steps {
                unstash 'source-code'
                withSonarQubeEnv('sonarqube-server') {
                    sh '''
                        /opt/sonar-scanner/bin/sonar-scanner \
                          -Dsonar.projectKey=django-sample-dev \
                          -Dsonar.sources=. \
                          -Dsonar.python.version=3.14 \
                          -Dsonar.sourceEncoding=UTF-8
                    '''
                }
            }
        }

        stage("Wait for Quality Gate") {
            agent { label 'built-in' }
            steps {
                sleep(time: 15, unit: 'SECONDS')
                timeout(time: 2, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Lint Code (PyLint)') {
            agent { label 'jenkins-build-node' }
            steps {
                unstash 'source-code'
                sh '''
                    . /venv/bin/activate
                    pip install -r requirements.txt
                    pylint --rcfile=.pylintrc greet/ sample/ > pylint-report.txt || true
                '''
            }
            post {
                always {
                    recordIssues(
                        enabledForFailure: true,
                        tools: [pyLint(pattern: 'pylint-report.txt')]
                    )
                }
            }
        }

        stage('Run Tests (PyTest)') {
            agent { label 'jenkins-build-node' }
            steps {
                unstash 'source-code'
                sh '''
                    . /venv/bin/activate
                    pip install -r requirements.txt
                    pytest --junitxml=pytest-results.xml
                '''
            }
            post {
                always {
                    junit 'pytest-results.xml'
                }
            }
        }

        /**************************************************************
         * Stage: Raise PR to Main
         **************************************************************/
        stage('Raise PR to Main') {
            agent { label 'jenkins-build-node' }
            steps {
                // IMPORTANT: Must checkout to restore .git folder
                checkout scm

                withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                    sh '''
                        set -e
                        export GH_TOKEN="$GITHUB_TOKEN"
                        export GITHUB_TOKEN="$GITHUB_TOKEN"

                        echo "Authenticated with GH CLI."

                        # Try to create the PR (ignore error if exists)
                        set +e
                        PR_OUTPUT=$(gh pr create --base main --head dev_sailiash \
                          --title "Auto PR: Merge dev_sailiash to main" \
                          --body "Pipeline succeeded on dev_sailiash. Requesting merge to main." 2>&1)
                        EC=$?
                        set -e

                        echo "$PR_OUTPUT"

                        if [ $EC -ne 0 ]; then
                            echo "PR already exists. Fetching existing PR..."
                            PR_URL=$(gh pr view dev_sailiash --json url -q '.url')
                        else
                            PR_URL="$PR_OUTPUT"
                        fi

                        echo "PR URL: $PR_URL"

                        PR_NUMBER=$(echo $PR_URL | awk -F/ '{print $NF}')
                        echo "PR Number: $PR_NUMBER"

                        # Attempt auto-merge (safe even if rules block it)
                        set +e
                        gh pr merge "$PR_NUMBER" --auto --merge
                        set -e || true

                        echo "PR stage completed succcccccccessfully......."
                    '''
                }
            }
        }

        /**************************************************************
         * Stage: Docker Build & Push
         **************************************************************/
        stage('Docker Build & Push') {
            agent { label 'jenkins-build-node' }
            steps {
                unstash 'source-code'

                sh '''
                    echo "$DOCKERHUB_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin

                    docker build -t ${IMAGE_NAME}:latest .
                    docker tag ${IMAGE_NAME}:latest ${DOCKERHUB_USER}/${IMAGE_NAME}:latest
                    docker push ${DOCKERHUB_USER}/${IMAGE_NAME}:latest
                '''
            }
        }

        /**************************************************************
         * Stage: Deploy
         **************************************************************/
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
        success {
            echo "✅ Pipeline completed successfully!"
        }
        failure {
            echo "❌ Pipeline failed!"
        }
    }
}
