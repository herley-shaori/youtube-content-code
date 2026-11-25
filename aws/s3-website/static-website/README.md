# Static website on Amazon S3

A static website kept in an Amazon S3 bucket, built in the Jakarta Region
(`ap-southeast-3`).

This is the first step: Terraform creates only the private bucket. The website files
and the way visitors reach them come in later steps.

## What Terraform creates

| Resource | Purpose |
| --- | --- |
| S3 bucket `static-website-stg-<suffix>` | Holds the website files |
| Public access block | Keeps the bucket private |

## Run it

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # then fill in your account ID and profile
terraform init
terraform apply
```

Remove everything with `terraform destroy`.
