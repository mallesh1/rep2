pipeline {
    stages {
        stage('Terraform test') {
            environment {
                AWS_DEFAULT_REGION="us-east-1"
            }
            steps {
                sh "AWS_DEFAULT_REGION=us-east-1 cd src && terraform init && terraform plan"
            }
        }
        stage('Terraform Apply us-east-1') {
            environment {
                AWS_DEFAULT_REGION="us-east-1"
            }
            steps {
                sh "cd src && terraform init && terraform apply --auto-approve"
            }
        }
        stage('Terraform Apply eu-west-1') {
            environment {
                AWS_DEFAULT_REGION="us-east-1"
            }
            steps {
                sh "AWS_DEFAULT_REGION=eu-west-1 cd src && terraform init && terraform apply --auto-approve"
            }
        }
    }
}