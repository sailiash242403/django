pipeline {
    agent none

    options {
        skipDefaultCheckout(true)
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

        stage('Raise PR to Main') {
            agent { label 'jenkins-build-node' }
            steps {
                // unstash 'source-code'
                // You MUST checkout to restore .git
                checkout scm

                withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                    sh '''
                        set -e

                        # Tell GitHub CLI to use the token from env
                        export GH_TOKEN="$GITHUB_TOKEN"
                        export GITHUB_TOKEN="$GITHUB_TOKEN"
                        echo "Authenticated with GH CLI."
                        
                        PR_URL=$(gh pr create --base main --head dev-sailiash \
                          --title "Auto PR: Merge devbranch to main" \
                          --body "Pipeline succeeded on devbranch. Requesting merge to main.")

                        echo "Created PR: $PR_URL"

                        PR_NUMBER=$(echo $PR_URL | awk -F/ '{print $NF}')

                        gh pr merge $PR_NUMBER --auto --merge
                    '''
                }
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
