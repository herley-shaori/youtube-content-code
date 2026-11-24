# AWS side of the lab: the image repository, the Fargate service that runs the
# website, and the load balancer in front of it. Run from a laptop.

provider "aws" {
  profile             = var.aws_profile
  region              = var.aws_region
  allowed_account_ids = [var.account_id]

  dynamic "assume_role" {
    for_each = var.assume_role_name == null ? [] : [var.assume_role_name]
    content {
      role_arn     = "arn:aws:iam::${var.account_id}:role/${assume_role.value}"
      session_name = "terraform-fargate-website"
    }
  }

  default_tags {
    tags = {
      "app-name"  = "fargate-website"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

locals {
  name           = "fargate-website-${var.environment}"
  container_name = "web"
  container_port = 8080
}

# --- Network: the default VPC and its public subnets ------------------------------

# ponytail: public subnets with public task IPs, so no NAT gateway is needed to pull
# the image. Use private subnets with VPC endpoints or NAT outside a lab.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "HTTPS from the internet to the load balancer"
  vpc_id      = data.aws_vpc.default.id
}

# Open to the internet, but the listener answers 403 without the secret header that
# only Cloudflare sends.
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.task.id
  ip_protocol                  = "tcp"
  from_port                    = local.container_port
  to_port                      = local.container_port
}

resource "aws_security_group" "task" {
  name        = "${local.name}-task"
  description = "Website tasks: reachable only from the load balancer"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "task_from_alb" {
  security_group_id            = aws_security_group.task.id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = local.container_port
  to_port                      = local.container_port
}

# Outbound HTTPS to pull the image from ECR and send logs.
resource "aws_vpc_security_group_egress_rule" "task_https" {
  security_group_id = aws_security_group.task.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# --- Amazon ECR: one image per Git tag --------------------------------------------

resource "aws_ecr_repository" "web" {
  name = local.name
  # A pushed tag can never be replaced, so v1.0 always means the same image.
  image_tag_mutability = "IMMUTABLE"
  # Lets terraform destroy remove the repository together with the lab images.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# --- Load balancer -----------------------------------------------------------------

resource "aws_lb" "web" {
  name               = local.name
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.public.ids
}

resource "aws_lb_target_group" "web" {
  name        = local.name
  vpc_id      = data.aws_vpc.default.id
  port        = local.container_port
  protocol    = "HTTP"
  target_type = "ip"
  # Short, so replaced tasks leave quickly during the lab. The default is 300.
  deregistration_delay = 15

  # A new task receives traffic only after /health has answered 200 twice.
  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Cloudflare connects to the origin over HTTPS, so the load balancer needs a
# certificate for the public name. The validation record is in cloudflare.tf.
resource "aws_acm_certificate" "web" {
  domain_name       = var.hostname
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "web" {
  certificate_arn         = aws_acm_certificate.web.arn
  validation_record_fqdns = [cloudflare_dns_record.acm_validation.name]
}

# Shared with Cloudflare, which adds it to every request it forwards.
resource "random_password" "origin_secret" {
  length  = 48
  special = false
}

# Every request is rejected unless the rule below matches.
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.web.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.web.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "from_cloudflare" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  condition {
    http_header {
      http_header_name = var.origin_header
      values           = [random_password.origin_secret.result]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# --- Amazon ECS on Fargate ---------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = local.name
}

resource "aws_cloudwatch_log_group" "web" {
  name              = "/ecs/${local.name}"
  retention_in_days = 7
}

data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Used by ECS itself to pull the image and write logs, not by the website.
resource "aws_iam_role" "task_execution" {
  name               = "${local.name}-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Terraform registers the first revision. After that the pipeline registers a new
# revision for every Git tag and points the service at it.
resource "aws_ecs_task_definition" "web" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = local.container_name
    image     = "${aws_ecr_repository.web.repository_url}:${var.initial_image_tag}"
    essential = true
    portMappings = [{
      containerPort = local.container_port
      protocol      = "tcp"
    }]
    # The website needs its heading. Without it /health answers 500.
    environment = [{
      name  = "GREETING"
      value = "Hello from Amazon ECS"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.web.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = local.container_name
      }
    }
  }])
}

resource "aws_ecs_service" "web" {
  name            = local.name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count

  # 1. Rolling update: never fewer healthy tasks than desired_count, and at most
  #    twice as many while old and new tasks run side by side.
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # 2. Circuit breaker: stop a deployment whose new tasks keep failing, and return
  #    the service to the last version that was healthy.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  health_check_grace_period_seconds = 15

  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = local.container_name
    container_port   = local.container_port
  }

  # The pipeline owns the task definition after the first apply.
  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_lb_listener_rule.from_cloudflare, aws_iam_role_policy_attachment.task_execution]
}
