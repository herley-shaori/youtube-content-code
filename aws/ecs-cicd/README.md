# ECS CI/CD

Tutorials on how container updates should reach Amazon ECS, built in the Jakarta
Region (`ap-southeast-3`). The apps are wrappers that illustrate each use case. Each
use case has its own folder with the application code in `app/` and the
infrastructure code in `terraform/`.

| Use case | What it shows |
| --- | --- |
| [fargate-website](fargate-website/) | Updating an ECS service from Amazon ECR with a rolling update and automatic rollback, shown with a Hello World website on Fargate |
