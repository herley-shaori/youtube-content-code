output "bucket_name" {
  description = "Bucket that will hold the website files."
  value       = aws_s3_bucket.website.bucket
}
