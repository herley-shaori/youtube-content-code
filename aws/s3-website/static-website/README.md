# Static website on Amazon S3

A static website kept in an Amazon S3 bucket, built in the Jakarta Region
(`ap-southeast-3`).

So far Terraform creates the private bucket and uploads the page in `app/index.html`.
The way visitors reach the page comes in a later step, so the page is not public yet.

## What Terraform creates

| Resource | Purpose |
| --- | --- |
| S3 bucket `static-website-stg-<suffix>` | Holds the website files |
| Public access block | Keeps the bucket private |
| Object `index.html` | The page from `app/index.html` |

## Run it

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # then fill in your account ID and profile
terraform init
terraform apply
```

Remove everything with `terraform destroy`.
