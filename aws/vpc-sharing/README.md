# VPC sharing

Tutorials on using one VPC from several AWS accounts of the same organization, built
in the Jakarta Region (`ap-southeast-3`). Each use case has its own folder with the
application code in `app/` and the infrastructure code in `terraform/`.

| Use case | What it shows |
| --- | --- |
| [shared-subnet-lambda](shared-subnet-lambda/) | A network account shares its subnets through AWS RAM, and an app account runs a Lambda function inside them |
