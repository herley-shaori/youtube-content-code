# OAuth 2.0 Implicit Flow with Cognito and API Gateway

Companion code for a tutorial that integrates Amazon Cognito, an API Gateway REST API,
and AWS Lambda with Terraform. The Lambda function uses Python 3.12 and returns
`Hello, World!`.

## Video

The video link is not published yet.

## Prerequisites

- Terraform CLI with access to download the AWS, Random, Local, and Null providers.
  This older example does not pin Terraform or provider versions.
- AWS CLI with credentials for a practice account that can manage the example
  resources.
- The `zip` utility, which the Terraform configuration calls to package the Lambda
  function.
- AWS Region `ap-southeast-3` (Jakarta), as set in `providers.tf`.

## Folder contents

| File | Purpose |
| --- | --- |
| `providers.tf` | Provider configuration and AWS Region. |
| `variables.tf` | Project name used to name resources. |
| `cognito.tf` | User pool, implicit-flow app client, domain, and demo user creation. |
| `apigw.tf` | REST API, Cognito authorizer, Lambda integration, and `dev` stage. |
| `lambda.tf` | IAM role, plus packaging and deployment of the Lambda function. |
| `lambda_function.py` | Python handler for the sample response. |
| `locals.tf` | Tags for the Lambda function. |

## Configuration

Read the Terraform files before deploying. The default project name is
`oauth2-implicit-apigateway-authorizer`. It is also used for the Cognito domain, so
you may need to change it to a name that is still available.

The code uses the demo user `herley@mailinator.com` in `cognito.tf` and Postman
callback and logout URLs in the app client configuration. Replace them with your own
values before trying it. Do not use this example for personal credentials or
production users.

You can set the project name in a local `terraform.tfvars` file:

```hcl
project_name = "your-unique-project-name"
```

Git ignores that file and the Terraform state. Use an AWS CLI profile or another
local AWS credential mechanism; never write access keys in code.

## Validate and deploy

Run from this tutorial folder:

```sh
cd aws/oauth2-implicit-cognito-aws-apigw
terraform init
terraform validate
terraform plan
```

Review the plan and the potential cost of the AWS resources. When the configuration
is right, deploy as a separate step:

```sh
terraform apply
```

The deployment also runs the AWS CLI to create the demo Cognito user and the `zip`
utility to package the Lambda function. These commands are a guide for viewers;
cloning the repository does not create any AWS resources.

## Expected result

The configuration defines a `POST /serve` endpoint on the `dev` stage. After you
complete the Cognito sign-in flow and get a valid ID token for the user pool, send the
token in the `Authorization` header when calling the API Gateway endpoint. The Lambda
handler returns status `200` with the body `Hello, World!`.

Find the API URL and the app client details in the AWS console; this example does not
provide Terraform outputs for them yet.

## Clean up

From the same tutorial folder, with the same state and AWS account:

```sh
terraform plan -destroy
terraform destroy
```

Review the resources to be deleted before approving. If the deployment failed or did
not finish, check for the demo user created through the AWS CLI.

## Notes and limitations

- This is an older implicit-flow example, not a complete sign-in application. It
  does not include a sign-in UI or an HTTP client example.
- The demo user's temporary password is generated randomly and stored in the state;
  the output is marked sensitive. Changing the initial password is not automated.
- Creating the user through `local-exec` does not handle an existing user. Check the
  account state when you rerun a failed deployment.
- The Lambda IAM role does not attach a policy for writing CloudWatch logs.
- Provider versions are not pinned, and this deployment has not been re-verified.
  Check provider compatibility before following the demo.
