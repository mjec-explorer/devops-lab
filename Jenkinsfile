pipeline {
  agent any

  parameters {
    booleanParam(
      name: 'RUN_TESTS',
      defaultValue: true,
      description: 'Run unit tests - disable if EC2 is low on memory'
    )
  }

  environment {
    AWS_REGION            = "eu-central-1"
    ECR_REGISTRY          = "439475769023.dkr.ecr.eu-central-1.amazonaws.com"
    IMAGE                 = "439475769023.dkr.ecr.eu-central-1.amazonaws.com/devopslab-app"
    ECS_CLUSTER           = "devopslab-cluster"
    ECS_SERVICE           = "devopslab-app"
    ECS_EXECUTION_ROLE    = "arn:aws:iam::439475769023:role/devopslab-ecs-execution"
    ALB_DNS               = "devopslab-alb-1455102833.eu-central-1.elb.amazonaws.com"
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
      when {
        expression { params.RUN_TESTS == true }
      }
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

          aws ecs register-task-definition \
            --family devopslab-app \
            --network-mode awsvpc \
            --requires-compatibilities FARGATE \
            --cpu 256 \
            --memory 512 \
            --execution-role-arn $ECS_EXECUTION_ROLE \
            --container-definitions "[{
              \"name\": \"app\",
              \"image\": \"$IMAGE:$GIT_SHA\",
              \"essential\": true,
              \"portMappings\": [{
                \"containerPort\": 8000,
                \"protocol\": \"tcp\"
              }],
              \"environment\": [{
                \"name\": \"GIT_SHA\",
                \"value\": \"$GIT_SHA\"
              }],
              \"logConfiguration\": {
                \"logDriver\": \"awslogs\",
                \"options\": {
                  \"awslogs-group\": \"/ecs/devopslab-app\",
                  \"awslogs-region\": \"$AWS_REGION\",
                  \"awslogs-stream-prefix\": \"ecs\"
                }
              }
            }]" \
            --region $AWS_REGION

          TASK_DEF=$(aws ecs describe-task-definition \
            --task-definition devopslab-app \
            --region $AWS_REGION \
            --query 'taskDefinition.taskDefinitionArn' \
            --output text)

          echo "New task definition: $TASK_DEF"

          aws ecs update-service \
            --cluster $ECS_CLUSTER \
            --service $ECS_SERVICE \
            --task-definition $TASK_DEF \
            --force-new-deployment \
            --region $AWS_REGION

          echo "Waiting for ECS service to stabilize..."
          aws ecs wait services-stable \
            --cluster $ECS_CLUSTER \
            --services $ECS_SERVICE \
            --region $AWS_REGION

          curl -fs http://$ALB_DNS/health
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
