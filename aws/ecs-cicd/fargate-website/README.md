# Updating an Amazon ECS service from Amazon ECR

A Hello World website runs as two Fargate tasks behind a load balancer. Pushing a Git
tag builds a container image, stores it in Amazon ECR under that version, and updates
the ECS service with a rolling update. When the new version is unhealthy, the
deployment circuit breaker returns the service to the last healthy version.

## Video

Not published yet.

## Prerequisites

- Terraform 1.10 or later, Docker, Python 3.13, the AWS CLI, and the GitHub CLI.
- An AWS account, and a profile that can reach it.
- A domain on Cloudflare, and an API token with **Zone Read**, **DNS Edit**,
  **Zone WAF Edit**, and **Transform Rules Edit** on that zone.
- Your own copy of this repository on GitHub, with a token that has admin access.

## Folder contents

| Path | Contents |
| --- | --- |
| `app/src/server.py` | The website: `/` shows the version, `/health` is for the load balancer |
| `app/Dockerfile` | The container image. The version comes from the Git tag at build time |
| `app/tests/` | Sanity tests, one suite per pipeline job |
| `terraform/` | ECR, ECS, load balancer, IAM roles, Cloudflare records and rules, GitHub environment |
| `.github/workflows/fargate-website-deploy.yml` (repository root) | The pipeline |

## What Terraform creates

| Side | Resources |
| --- | --- |
| AWS | ECR repository with immutable tags, ECS cluster, task definition and Fargate service (2 tasks), Application Load Balancer with an HTTPS listener, ACM certificate, security groups, log group (7 days), task execution role, deploy role for GitHub Actions |
| Cloudflare | Proxied DNS record, certificate validation record, WAF custom rule that blocks the hostname until `public_access = true`, request header rule that adds the origin secret |
| GitHub | Environment `app-stg` that only tags matching `fargate-website-stg-v*` can use, secrets `AWS_ROLE_ARN`, `ECR_REPOSITORY_URL`, variables `AWS_REGION`, `ECS_CLUSTER`, `ECS_SERVICE`, `TASK_FAMILY`, `CONTAINER_NAME` |

It uses the default VPC and its public subnets. The tasks get public IPs so they can
pull the image without a NAT gateway, and their security group accepts traffic only
from the load balancer.

## The two ECS settings this lab is about

```hcl
resource "aws_ecs_service" "web" {
  desired_count = 2

  # 1. Rolling update
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # 2. Circuit breaker
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}
```

With 100 and 200, ECS starts two new tasks next to the two old ones and stops the old
tasks only after the new ones pass the `/health` check. For a moment the load balancer
serves both versions. If the new tasks never become healthy, the circuit breaker stops
the deployment and the old tasks keep serving.

## How the website is protected

1. **Cloudflare is the only entrance.** The DNS record is proxied. With
   `public_access = false` (the default) a WAF custom rule blocks every request.
2. **The load balancer rejects direct calls.** Cloudflare adds the header
   `x-origin-verify` with a random secret to every request. The listener forwards only
   requests that carry it and answers `403 Forbidden` to everything else.
3. **No access keys.** GitHub Actions gets one-hour credentials through OpenID
   Connect. Only jobs in the `app-stg` environment of this repository can assume the
   role, and the role can only push to this ECR repository and update this service.

## How to run

Create the infrastructure from `terraform/`:

```sh
cp terraform.tfvars.example terraform.tfvars   # fill in your values
export TF_VAR_cloudflare_api_token="..."       # never put it in a file in the repo
export GITHUB_TOKEN="$(gh auth token)"
terraform init
terraform plan
terraform apply
```

The service starts with a task definition that points to image `v1.0`, which does not
exist yet, so no task runs until the first release. Then release from the repository
root. Each tag must point to a commit on `master`:

```sh
git tag fargate-website-stg-v1.0
git push origin fargate-website-stg-v1.0
```

The pipeline runs the sanity tests in parallel, builds the image, pushes it to ECR as
`v1.0`, registers a task definition revision for it, updates the service, and waits
for the rollout. Set `public_access = true` and apply again to open the website.

The lab uses three versions:

| Tag | Change | Expected result |
| --- | --- | --- |
| `fargate-website-stg-v1.0` | First release | Two tasks show "Version v1.0" |
| `fargate-website-stg-v2.0` | The page text changes | Old and new tasks run side by side, then the page shows "Version v2.0" |
| `fargate-website-stg-v3.0` | `/health` fails in ECS only | New tasks never become healthy, the deployment is rolled back, the page still shows "Version v2.0", and the pipeline fails |

To watch visitors during an update, call the website every second:

```sh
while true; do curl -s -o /dev/null -w "%{http_code} " https://hello.example.com/; sleep 1; done
```

To run the website and its tests without AWS, from `app/`:

```sh
python -m unittest -v tests.test_server
docker build --build-arg APP_VERSION=v1.0 -t fargate-website .
docker run --rm -p 8080:8080 fargate-website   # http://localhost:8080
```

## Clean up

```sh
terraform destroy
```

This removes everything Terraform created, including the ECR repository and its
images. Task definition revisions registered by the pipeline are not in the Terraform
state, so they stay in the account. They cost nothing. Deregister them in the ECS
console if you want them gone.

## Notes and limitations

- An Application Load Balancer and two Fargate tasks are billed for as long as they
  exist. Destroy the lab when you are done.
- Public subnets with public task IPs keep the lab small. Outside a lab, put the tasks
  in private subnets with VPC endpoints or a NAT gateway.
- The load balancer accepts connections from any address and relies on the secret
  header. To also restrict it by network, allow only Cloudflare's IP ranges in its
  security group.
- Image tags are immutable, so a version cannot be pushed twice. Release a fix under a
  new version.
