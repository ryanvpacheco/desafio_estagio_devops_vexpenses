#Variável para definir a região AWS dinamicamente
variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1" # Região padrão, mas pode ser alterada ao rodar o Terraform
}

provider "aws" {
  region = var.aws_region
}

# Seleciona automaticamente uma zona de disponibilidade válida dentro da região escolhida
data "aws_availability_zones" "available" {}

# Variáveis para personalização dos recursos
variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"
}

variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "SeuNome"
}

# Geração de chave SSH para acesso seguro à instância EC2
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Criando a VPC para isolar os recursos
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Criando uma Subnet dentro da VPC e selecionando automaticamente uma zona válida
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0] # Escolhe a primeira zona disponível
}

# Criando um Gateway de Internet para permitir comunicação externa
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
}

# Criando uma Tabela de Rotas para direcionar tráfego à internet
resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }
}

# Criando um Grupo de Segurança com acesso restrito via VPN
resource "aws_security_group" "sg" {
  vpc_id = aws_vpc.main_vpc.id


  # Permite acesso SSH apenas a IPs da VPN
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.168.100.0/24"]
  }

# Permite acesso HTTP público (porta 80)
# Será utilizada para disponibilizar o Nginx, que será instalado automaticamente na seção Criando a instância EC2 com Nginx instalado automaticamente.
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Busca automática da AMI do Ubuntu mais recente para a região escolhida
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # ID oficial da Canonical (Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Criando a instância EC2 com Nginx instalado automaticamente
resource "aws_instance" "ec2" {
  ami           = data.aws_ami.ubuntu.id # Busca automática da AMI mais recente
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ec2_key_pair.key_name
  subnet_id     = aws_subnet.main_subnet.id
  vpc_security_group_ids = [aws_security_group.sg.id]

  # Script de inicialização para instalar e iniciar o Nginx automaticamente
  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install nginx -y
    systemctl start nginx
    systemctl enable nginx
  EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
  }
}

# Associando um Elastic IP para garantir um IP fixo para a EC2
resource "aws_eip" "elastic_ip" {
  instance = aws_instance.ec2.id
}
