output "website_url" {
  value = "https://${var.hostname}"
}

output "bucket_name" {
  description = "Bucket that holds the website files."
  value       = aws_s3_bucket.website.bucket
}

output "s3_website_endpoint" {
  description = "Direct calls to this name get 403. Use it to show that Cloudflare is the only entrance."
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
}
