pipeline {
  agent any

  environment {
    GHCR_USER  = "mjec-explorer"
    IMAGE      = "ghcr.io/mjec-explorer/devops-lab-app"
    GHCR_TOKEN = credentials('GHCR_TOKEN')
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Unit Tests') {
      steps {
        sh '''
          set -eux
          docker build --target test -t devops-lab-app:test ./app
        '''
      }
    }

    stage('Build Image') {
      steps {
        sh '''
          set -eux
          GIT_SHA=$(git rev-parse --short HEAD)
          echo "$GIT_SHA" > .gitsha
          docker build --target runtime \
	    -t "$IMAGE:$GIT_SHA" \
            -t "$IMAGE:latest" \
            ./app
        '''
      }
    }

    stage('Push Image') {
      steps {
        sh '''
          set -eux
          echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
          GIT_SHA=$(cat .gitsha)
          docker push "$IMAGE:$GIT_SHA"
          docker push "$IMAGE:latest"
        '''
      }
    }
  }
}
