output "load_balancer_dns_name" {
  description = "Public DNS name for the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "auth_service_url" {
  description = "URL de acesso para o serviço de autenticação"
  value       = format("http://%s%s", aws_lb.main.dns_name, local.service_paths.auth)
}

output "user_service_url" {
  description = "URL de acesso para o serviço de usuários"
  value       = format("http://%s%s", aws_lb.main.dns_name, local.service_paths.user)
}

output "venda_service_url" {
  description = "URL de acesso para o serviço de vendas"
  value       = format("http://%s%s", aws_lb.main.dns_name, local.service_paths.venda)
}

output "database_endpoint" {
  description = "Endpoint de conexão para o banco de dados"
  value       = module.rds.rds_endpoint
}
