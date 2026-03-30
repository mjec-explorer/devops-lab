pipeline {
  agent any

  environment {
    AWS_REGION            = "eu-central-1"
    ECR_REGISTRY          = "439475769023.dkr.ecr.eu-central-1.amazonaws.com"
    IMAGE                 = "439475769023.dkr.ecr.eu-central-1.amazonaws.com/devopslab-app"
    AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
    AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
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
          GIT_SHA=$(cat .gitsha)
          aws ecr get-login-password --region $AWS_REGION | \
            docker login --username AWS --password-stdin $ECR_REGISTRY
          docker push "$IMAGE:$GIT_SHA"
        '''
      }
    }

    stage('Deploy') {
      steps {
        sh '''
          set -eux
          GIT_SHA=$(cat .gitsha)
	  export GIT_SHA
          aws ecr get-login-password --region $AWS_REGION | \
            docker login --username AWS --password-stdin $ECR_REGISTRY

          # Pull the exact SHA-tagged image before deploying
          docker pull "$IMAGE:$GIT_SHA"

          # Store the currently running image tag so we can roll back if needed
          PREVIOUS_TAG=$(docker inspect \
            --format='{{index .Config.Image}}' \
            devops_lab-app-1 2>/dev/null || echo "none")
          echo "$PREVIOUS_TAG" > .previous_tag
          echo "Previous image: $PREVIOUS_TAG"

          # Deploy only the app container 
          IMAGE_TAG=$GIT_SHA docker compose \
            -p devops_lab \
            -f docker-compose.yml \
            up -d --no-deps --force-recreate app

          # Get the new container ID
          CID=$(docker compose -p devops_lab -f docker-compose.yml ps -q app)
          echo "New container ID: $CID"

          # BUG FIX: Wait until healthy — loop until status = healthy, exit if never reached
          # Previous version had inverted logic: [ "$status" = "healthy" ] || exit 1
          # That exited immediately on the first "starting" check.
          echo "Waiting for app container to become healthy (max 30s)..."
          HEALTHY=0
          for i in $(seq 1 15); do
            STATUS=$(docker inspect \
              --format="{{if .State.Health}}{{.State.Health.Status}}{{else}}nohealth{{end}}" \
              "$CID" 2>/dev/null || echo "inspect-failed")
            echo "  Attempt $i/15 — status: $STATUS"

            if [ "$STATUS" = "healthy" ]; then
              echo "  Container is healthy."
              HEALTHY=1
              break
            fi

            # If the container exited entirely, no point waiting
            RUNNING=$(docker inspect --format="{{.State.Running}}" "$CID" 2>/dev/null || echo "false")
            if [ "$RUNNING" = "false" ]; then
              echo "  Container exited unexpectedly — aborting."
              break
            fi

            sleep 2
          done

          # Rollback if unhealthy
          if [ "$HEALTHY" = "0" ]; then
            echo "ERROR: App never became healthy. Rolling back to previous image."
            PREV=$(cat .previous_tag)
            if [ "$PREV" != "none" ] && [ -n "$PREV" ]; then
              docker pull "$PREV" || true
              docker compose \
                -p devops_lab \
                -f docker-compose.yml \
                up -d --no-deps --force-recreate app || true
            fi
            exit 1
          fi

          # Final end-to-end check through nginx
          curl -fs http://nginx/health
          echo ""
          echo "Deploy successful: $GIT_SHA"
        '''
      }
    }
  }

  post {
    failure {
      echo 'Pipeline failed. Check deploy logs above for rollback status.'
    }
    success {
      echo 'Pipeline passed. Stack is healthy.'
    }
  }
}
