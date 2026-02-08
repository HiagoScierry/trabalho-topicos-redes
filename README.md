# Infraestrutura Terraform para Microservicos AWS

Este diretorio provisiona toda a infraestrutura AWS necessaria para executar tres servicos (auth, user e venda) em ECS Fargate, alem de rede dedicada e banco de dados relacional.

## Visao geral da arquitetura

- **Rede (VPC)**: VPC /16 com duas sub-redes publicas e duas privadas distribuidas entre zonas de disponibilidade.
- **Banco de dados (RDS MySQL)**: instancia `db.t3.micro` com grupo de sub-redes privado.
- **Compute (ECS Fargate)**: cada microservico possui cluster, task definition e service proprios, rodando container exposto na porta 3000.

```
main.tf
├── module "vpc"         -> modules/vpc
├── module "rds"         -> modules/rds
├── module "ecs_auth"    -> modules/ecs_service
├── module "ecs_user"    -> modules/ecs_service
└── module "ecs_venda"   -> modules/ecs_service
```

## Estrutura dos modulos

| Modulo | Recursos principais | Observacoes |
| --- | --- | --- |
| `modules/vpc` | `aws_vpc`, sub-redes publicas e privadas, AZ lookup | Expande para 4 sub-redes automaticas com CIDR gerado via `cidrsubnet`. |
| `modules/rds` | `aws_db_subnet_group`, `aws_db_instance` | Banco MySQL basico (`db.t3.micro`). Ajuste credenciais antes do uso em producao. |
| `modules/ecs_service` | `aws_ecs_cluster`, `aws_ecs_task_definition`, `aws_ecs_service`, IAM Execution Role | Task definition do tipo Fargate (256 vCPU / 512 MB) e porta 3000 exposta. |

## Requisitos

- Terraform `>= 1.3.0`
- Provider AWS `>= 5.0`
- Credenciais AWS configuradas (`AWS_PROFILE`, `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` ou SSO)

## Variaveis

| Variavel | Descricao | Valor padrao |
| --- | --- | --- |
| `region` | Regiao onde os recursos serao criados | `us-east-1` |
| `auth_image` | Imagem do container do servico de autenticacao | obrigatoria |
| `user_image` | Imagem do container do servico de usuario | obrigatoria |
| `venda_image` | Imagem do container do servico de venda | obrigatoria |
| `db_username` | Usuario padrao do banco MySQL (injetado nas tasks) | `admin` |
| `db_password` | Senha padrao do banco MySQL (injetada nas tasks) | `admin123` |
| `db_port` | Porta exposta pelo banco MySQL | `3306` |
| `jwt_secret` | Chave usada na assinatura dos tokens JWT | valor padrao fornecido |
| `jwt_expiry` | Tempo de expiracao dos tokens JWT | `1h` |

Defina as variaveis no arquivo `terraform.tfvars` ou via CLI:

```hcl
region      = "us-east-1"
auth_image  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/auth:latest"
user_image  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/user:latest"
venda_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/venda:latest"
db_username = "admin"
db_password = "admin123"
db_port     = 3306
jwt_secret  = "bcdc3ddc13b516672e8efccb94e41f052aa5c08c3c516b398ebfbb1326780bb0"
jwt_expiry  = "1h"
```

> **Dica**: utilize tags imutaveis (por exemplo `:1.0.3` ou digest `@sha256`) para forcar o ECS a detectar novas imagens.

Cada task ECS recebe automaticamente `NODE_ENV`, `PORT=3000` e as variaveis `DB_HOST`, `DB_USER`, `DB_PASS`, `DB_PORT`, `JWT_SECRET` e `JWT_EXPIRY`, garantindo configuracao consistente para conexao ao banco e autenticacao JWT.

## Como usar

1. **Inicializacao**
   ```bash
   terraform init
   ```
2. **Validacao e plano**
   ```bash
   terraform fmt
   terraform validate
   terraform plan -out tfplan
   ```
3. **Aplicar**
   ```bash
   terraform apply tfplan
   ```
4. **Destruir** (quando nao precisar mais dos recursos)
   ```bash
   terraform destroy
   ```

## Boas praticas sugeridas

- Configure parametros sensiveis (usuario/senha do RDS) via `terraform.tfvars` seguros ou AWS Secrets Manager.
- Centralize logs e metricas habilitando CloudWatch Logs para as task definitions.
- Utilize um ALB ou API Gateway para expor os servicos ao publico se necessario.
- Integre o pipeline de build para atualizar `terraform.tfvars` ou rodar `terraform apply` sempre que publicar uma nova imagem.

## Recursos de saida

Apos o `apply`, voce recebera:

- IDs da VPC e sub-redes (`module.vpc.*`)
- Endpoint do RDS (`module.rds.rds_endpoint`)
- Nome dos servicos ECS (`module.ecs_* .service_name`)

Sinta-se a vontade para adaptar os modulos ou adicionar novos servicos seguindo o padrao existente.
