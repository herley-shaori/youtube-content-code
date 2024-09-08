# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = var.project_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Specify the file to zip
data "local_file" "file_to_zip" {
  filename = "lambda_function.py"
}

# Create a null resource to run the zip command
resource "null_resource" "zip_file" {
  provisioner "local-exec" {
    command = <<EOT
      if [ -f lambda_function.zip ]; then rm lambda_function.zip; fi
      zip lambda_function.zip ${data.local_file.file_to_zip.filename}
    EOT
  }

  triggers = {
    file_sha256 = data.local_file.file_to_zip.content_sha256
  }
}

resource "aws_lambda_function" "example_lambda" {
  depends_on    = [null_resource.zip_file]
  filename      = "lambda_function.zip"
  function_name = var.project_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  tags          = local.tags
}