output "website_url" {
  value = "https://${var.hostname}"
}

output "ecr_repository" {
  value = aws_ecr_repository.web.name
}

output "ecs_cluster" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service" {
  value = aws_ecs_service.web.name
}

output "load_balancer_dns_name" {
  description = "Direct calls to this name get 403. Use it to show that Cloudflare is the only entrance."
  value       = aws_lb.web.dns_name
}
