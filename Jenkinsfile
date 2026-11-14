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
        // Get Docker Hub creds securely from Jenkins Credentials (ID: dockerhub)
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sh 'echo $DH_PASS | docker login -u $DH_USER --password-stdin'         // --password-stdin avoids exposing the password as a command-line argument
          sh 'docker push ${IMAGE_REPO}:latest'                                 // Push the latest image tag
          sh 'docker push ${IMAGE_REPO}:${BUILD_NUMBER}'                       // Push the build-number-specific image tag
        }
      }
    }

    stage('Deploy') {
      steps {
        // SSH into the app server with the key stored in Jenkins (ID: app-ssh)
        sshagent(credentials: ['app-ssh']) {
          withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
            sh '''
              # Copy the deploy script to the app server
              scp -o StrictHostKeyChecking=no deploy.sh ec2-user@172.31.14.85:/home/ec2-user/deploy.sh

              # Log in to Docker Hub on the server (needed for the private prod repo), then run deploy.sh
              echo $DH_PASS | ssh -o StrictHostKeyChecking=no ec2-user@172.31.14.85 "docker login -u $DH_USER --password-stdin && chmod +x deploy.sh && ./deploy.sh ${IMAGE_REPO} latest"
            '''
          }
        }
      }
    }

  }

  post {
    always {
      // Always log out of Docker Hub on the Jenkins server
      sh 'docker logout || true'
    }
  }
}