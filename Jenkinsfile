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
    stage('Deploy to ECS') {
      steps {
        sh '''
          set -eux
          GIT_SHA=$(cat .gitsha)

          aws ecs update-service \
            --cluster devopslab-cluster \
            --service devopslab-app \
            --force-new-deployment \
            --region $AWS_REGION

          echo "Waiting for ECS service to stabilize..."
          aws ecs wait services-stable \
            --cluster devopslab-cluster \
            --services devopslab-app \
            --region $AWS_REGION

          curl -fs http://devopslab-alb-847836574.eu-central-1.elb.amazonaws.com/health
          echo ""
          echo "Deploy successful: $GIT_SHA"
        '''
      }
    }
  }
  post {
    failure {
      echo 'Pipeline failed. Check deploy logs above.'
    }
    success {
      echo 'Pipeline passed. Stack is healthy.'
    }
  }
}
