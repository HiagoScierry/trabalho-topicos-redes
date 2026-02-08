variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "auth_image" {
  description = "Docker image para o serviço de autenticação"
  type        = string
}

variable "user_image" {
  description = "Docker image para o serviço de usuário"
  type        = string
}

variable "venda_image" {
  description = "Docker image para o serviço de venda"
  type        = string
}

variable "db_username" {
  description = "Usuario utilizado pelo banco RDS"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Senha utilizada pelo banco RDS"
  type        = string
  default     = "admin123"
}

variable "db_port" {
  description = "Porta de conexao do banco RDS"
  type        = number
  default     = 3306
}

variable "db_name" {
  description = "Nome do banco de dados principal"
  type        = string
  default     = "market"
}

variable "db_admin_cidrs" {
  description = "Lista de CIDRs autorizados a acessar diretamente o banco (ex.: IP pessoal). Deixe vazio para desabilitar acesso externo."
  type        = list(string)
  default     = []
}

variable "jwt_secret" {
  description = "Chave secreta utilizada para assinar os JWTs"
  type        = string
  default     = "bcdc3ddc13b516672e8efccb94e41f052aa5c08c3c516b398ebfbb1326780bb0"
}

variable "jwt_expiry" {
  description = "Tempo de expiracao dos tokens JWT"
  type        = string
  default     = "1h"
}
