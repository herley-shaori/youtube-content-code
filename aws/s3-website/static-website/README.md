# Static website on Amazon S3

A static website served from an Amazon S3 bucket in the Jakarta Region
(`ap-southeast-3`), with Cloudflare as the only public entrance.

```text
visitor --HTTPS--> Cloudflare --HTTP + secret--> S3 website endpoint --> index.html
```

The page is in `app/index.html`. Terraform in `terraform/` creates everything else.

## What Terraform creates

| Resource | Purpose |
| --- | --- |
| S3 bucket named after the hostname | Holds the website files. S3 website hosting finds the bucket by the request's Host header |
| Public access block | All four settings stay on |
| Object `index.html` | The page from `app/index.html` |
| Website configuration | Makes `/` answer with `index.html` |
| Bucket policy | Allows reading only from Cloudflare's addresses and only with the secret |
| Cloudflare DNS record | Proxied CNAME from the hostname to the S3 website endpoint |
| Cloudflare custom rule | Blocks all traffic to the hostname until `public_access = true` |
| Cloudflare request header rule | Adds the secret to every request for the hostname |
| Cloudflare configuration rule | Lets Cloudflare call the endpoint over HTTP, because it has no HTTPS |

## Things to know

- Traffic between Cloudflare and S3 is not encrypted. Visitors use HTTPS up to
  Cloudflare. Use CloudFront with origin access control when that matters.
- S3 can only check the `Referer` or `User-Agent` header in a bucket policy, so the
  secret travels as `Referer`.
- A Cloudflare zone has one ruleset per phase. This lab owns the custom rules, request
  header rules and configuration rules of the zone, so use a zone without existing
  rules in those three places.
- The Cloudflare token needs Zone Read, DNS Edit, Zone WAF Edit, Transform Rules Edit
  and Config Rules Edit on the zone.

## Run it

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # then fill in your own values
export TF_VAR_cloudflare_api_token=...         # never write the token to a file in Git
terraform init
terraform apply
```

The website answers 403 until you set `public_access = true` and apply again.
A direct call to the `s3_website_endpoint` output always answers 403.

Remove everything with `terraform destroy`.
