pipeline {
  agent any
  stages {
    stage('Set repo') {
      steps {
        script {
          // master -> prod repo, anything else (dev) -> dev repo
          env.IMAGE_REPO = (env.BRANCH_NAME == 'master') ? 'kannansudalai/prod' : 'kannansudalai/dev'
        }
        echo "Branch: ${env.BRANCH_NAME}  ->  Image repo: ${env.IMAGE_REPO}"
      }
    }
    stage('Build') {
      steps {
        sh './build.sh ${IMAGE_REPO} latest'
        sh 'docker tag ${IMAGE_REPO}:latest ${IMAGE_REPO}:${BUILD_NUMBER}'
      }
    }
    stage('Push') {
      steps {
        // get Docker Hub creds securely from Jenkins Credentials, Credentials ID: dockerhub
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) { 
          sh 'echo $DH_PASS | docker login -u $DH_USER --password-stdin'   // Login to Docker Hub using password from Jenkins credentials,--password-stdin avoids exposing password as a command-line argument
          sh 'docker push ${IMAGE_REPO}:latest'                            // Push the latest image tag
          sh 'docker push ${IMAGE_REPO}:${BUILD_NUMBER}'                   // Push the build-number-specific image tag
        }
      }
    }
  }
  post {
    always { sh 'docker logout || true' }
  }
}