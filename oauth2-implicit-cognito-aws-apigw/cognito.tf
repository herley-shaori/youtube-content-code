# Cognito User Pool
resource "aws_cognito_user_pool" "pool" {
  name = var.project_name
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "client" {
  name         = var.project_name
  user_pool_id = aws_cognito_user_pool.pool.id

  allowed_oauth_flows                  = ["implicit"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  callback_urls                = ["https://oauth.pstmn.io/v1/callback"]
  logout_urls                  = ["https://oauth.pstmn.io/v1/logout"]
  supported_identity_providers = ["COGNITO"]
  generate_secret              = false
}

# Cognito User Pool Domain
resource "aws_cognito_user_pool_domain" "main" {
  domain       = var.project_name
  user_pool_id = aws_cognito_user_pool.pool.id
}

# Random Password Generator
resource "random_password" "user_password" {
  length  = 12
  special = true
  numeric = true
  lower   = true
}

# Add User to Cognito User Pool
# Add User to Cognito User Pool
resource "null_resource" "add_user" {
  provisioner "local-exec" {
    command = <<EOT
      aws cognito-idp admin-create-user \
        --user-pool-id ${aws_cognito_user_pool.pool.id} \
        --username "herley@mailinator.com" \
        --user-attributes Name=email,Value=herley@mailinator.com Name=email_verified,Value=true \
        --temporary-password "${random_password.user_password.result}" \
        --desired-delivery-mediums EMAIL
    EOT
  }
  depends_on = [aws_cognito_user_pool.pool, random_password.user_password]
}

# Output the Generated Password for Debugging Purposes
output "cognito_user_password" {
  value = random_password.user_password.result
  sensitive = true
}