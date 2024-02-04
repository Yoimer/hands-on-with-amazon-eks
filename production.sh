export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text | xargs)

# #  Create the Production DynamoDB Tables
echo "***************************************************"
echo "********* Production DynamoDB Tables ***"
echo "***************************************************"

    ( cd ./clients-api/infra/cloudformation && ./create-dynamodb-table.sh production ) & \
    ( cd ./inventory-api/infra/cloudformation && ./create-dynamodb-table.sh production ) & \
    ( cd ./renting-api/infra/cloudformation && ./create-dynamodb-table.sh production ) & \
    ( cd ./resource-api/infra/cloudformation && ./create-dynamodb-table.sh production ) &
    wait

# Create IAM Policies of Bookstore Microservices
echo "***************************************************"
echo "********* IAM Policies of Bookstore Microservices ***"
echo "***************************************************"

    ( cd clients-api/infra/cloudformation && ./create-iam-policy.sh production ) & \
    ( cd resource-api/infra/cloudformation && ./create-iam-policy.sh production ) & \
    ( cd inventory-api/infra/cloudformation && ./create-iam-policy.sh production ) & \
    ( cd renting-api/infra/cloudformation && ./create-iam-policy.sh production ) &

    wait

# Create IAM Service Accounts
echo "***************************************************"
echo "********* IAM Service Accounts ***"
echo "***************************************************"

    resource_iam_policy=$(aws cloudformation describe-stacks --stack production-iam-policy-resource-api --query "Stacks[0].Outputs[0]" | jq .OutputValue | tr -d '"')
    renting_iam_policy=$(aws cloudformation describe-stacks --stack production-iam-policy-renting-api --query "Stacks[0].Outputs[0]" | jq .OutputValue | tr -d '"')
    inventory_iam_policy=$(aws cloudformation describe-stacks --stack production-iam-policy-inventory-api --query "Stacks[0].Outputs[0]" | jq .OutputValue | tr -d '"')
    clients_iam_policy=$(aws cloudformation describe-stacks --stack production-iam-policy-clients-api --query "Stacks[0].Outputs[0]" | jq .OutputValue | tr -d '"')
    
    
    eksctl create iamserviceaccount --name resources-api-iam-service-account \
        --namespace production \
        --cluster eks-acg \
        --attach-policy-arn ${resource_iam_policy} --approve
    eksctl create iamserviceaccount --name renting-api-iam-service-account \
        --namespace production \
        --cluster eks-acg \
        --attach-policy-arn ${renting_iam_policy} --approve
    eksctl create iamserviceaccount --name inventory-api-iam-service-account \
        --namespace production \
        --cluster eks-acg \
        --attach-policy-arn ${inventory_iam_policy} --approve
    eksctl create iamserviceaccount --name clients-api-iam-service-account \
        --namespace production \
        --cluster eks-acg \
        --attach-policy-arn ${clients_iam_policy} --approve 

# Installing the Production applications

echo "***************************************************"
echo "********* Installing the Production applications ***"
echo "***************************************************"

    sleep 360 # wait until everything has images. More or less, 5 minutes

    front_end_image_tag=$(aws ecr list-images --repository-name bookstore.front-end --query "imageIds[0].imageTag" --output text | xargs)
    clients_api_image_tag=$(aws ecr list-images --repository-name bookstore.clients-api --query "imageIds[0].imageTag" --output text | xargs)
    renting_api_image_tag=$(aws ecr list-images --repository-name bookstore.renting-api --query "imageIds[0].imageTag" --output text | xargs)
    resource_api_image_tag=$(aws ecr list-images --repository-name bookstore.resource-api --query "imageIds[0].imageTag" --output text | xargs)
    inventory_api_image_tag=$(aws ecr list-images --repository-name bookstore.inventory-api --query "imageIds[0].imageTag" --output text | xargs)

    ( cd ./resource-api/infra/helm-v5 && ./create.sh production ${resource_api_image_tag} ) & \
    ( cd ./clients-api/infra/helm-v5 && ./create.sh production ${clients_api_image_tag} ) & \
    ( cd ./inventory-api/infra/helm-v5 && ./create.sh production ${inventory_api_image_tag} ) & \
    ( cd ./renting-api/infra/helm-v5 && ./create.sh production ${renting_api_image_tag} ) & \
    ( cd ./front-end/infra/helm-v5 && ./create.sh production ${front_end_image_tag} ) &

    wait

# Automatic Deployment to Production Environment

echo "***************************************************"
echo "********* Automatic Deployment to Production Environment ***"
echo "***************************************************"

    ( cd Infrastructure/cloudformation/cicd && \
        aws cloudformation deploy \
            --stack-name inventory-api-codecommit-repo \
            --template-file cicd-5-deploy-prod.yaml \
            --capabilities CAPABILITY_IAM \
            --parameter-overrides \
                AppName=inventory-api ) & \
    ( cd Infrastructure/cloudformation/cicd && \
        aws cloudformation deploy \
            --stack-name resource-api-codecommit-repo \
            --template-file cicd-5-deploy-prod.yaml \
            --capabilities CAPABILITY_IAM \
            --parameter-overrides \
                AppName=resource-api ) & \
    ( cd Infrastructure/cloudformation/cicd && \
        aws cloudformation deploy \
            --stack-name renting-api-codecommit-repo \
            --template-file cicd-5-deploy-prod.yaml \
            --capabilities CAPABILITY_IAM \
            --parameter-overrides \
                AppName=renting-api ) & \
    ( cd Infrastructure/cloudformation/cicd && \
        aws cloudformation deploy \
            --stack-name clients-api-codecommit-repo \
            --template-file cicd-5-deploy-prod.yaml \
            --capabilities CAPABILITY_IAM \
            --parameter-overrides \
                AppName=clients-api ) & \
    ( cd Infrastructure/cloudformation/cicd && \
        aws cloudformation deploy \
            --stack-name front-end-codecommit-repo \
            --template-file cicd-5-deploy-prod.yaml \
            --capabilities CAPABILITY_IAM \
            --parameter-overrides \
                AppName=front-end ) &

    wait
