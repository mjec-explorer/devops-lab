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

    stage('Deploy') {
      steps {
        sh '''
          set -eux
          GIT_SHA=$(cat .gitsha)
          echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
          docker pull "$IMAGE:$GIT_SHA"
          IMAGE_TAG=$GIT_SHA docker compose -p devops_lab -f docker-compose.yml up -d --no-deps --force-recreate app
          CID=$(docker compose -p devops_lab -f docker-compose.yml ps -q app)

	  # wait until nginx->app works (avoid flaky 502)
          for i in {1..15}; do
            status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}nohealth{{end}}' "$CID" || true)
            echo "Health=$status"
            [ "$status" = "healthy" ] || { echo "App never became healthy"; exit 1; } 
	    sleep 2
          done

          curl -fs http://localhost/health
          echo "Deployed $GIT_SHA OK"
        '''
      }  
    }
  }
}
