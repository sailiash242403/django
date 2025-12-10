pipeline {
    agent none

    options {
        // Prevent Jenkins from doing an implicit checkout on every agent
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
            agent { label 'pynode' }
            steps {
                unstash 'source-code'
                sh '''
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
            agent { label 'pynode' }
            steps {
                unstash 'source-code'
                sh '''
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

        stage('Raise PR to Master') {
            agent { label 'built-in' }
            steps {
                withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                    sh '''
                        # Create PR and capture its URL
                        PR_URL=$(gh pr create --base master --head devbranch \
                          --title "Auto PR: Merge devbranch to master" \
                          --body "Pipeline succeeded on devbranch. Requesting merge to master.")

                        echo "Created PR: $PR_URL"

                        # Extract PR number from URL
                        PR_NUMBER=$(echo $PR_URL | awk -F/ '{print $NF}')

                        # Merge the PR explicitly by number
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
