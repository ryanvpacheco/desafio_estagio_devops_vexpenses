# **Tarefa 1**  
# **Análise Técnica do Código Terraform main.tf**  
## **Descrição Técnica**

### **1. Configuração do Provedor AWS**  
```hcl
provider "aws" {
  region = "us-east-1"
}
```
Este bloco define o **provedor de nuvem** (AWS) e a **região** onde os recursos serão criados. No caso, está sendo usada a região **`us-east-1` (Leste dos EUA)**. Essa escolha afeta aspectos como custo, latência e disponibilidade dos serviços da AWS.

### **2. Definição de Variáveis**  
```hcl
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
```
O código define duas **variáveis**:
- **`projeto`**: Usada para definir o nome do projeto, facilitando a personalização do código.
- **`candidato`**: Usada para personalizar os recursos com o nome do candidato.

O uso de variáveis permite que o código seja facilmente reutilizado para diferentes projetos ou ambientes sem necessidade de editar os valores diretamente.

### **3. Geração de Chave SSH**  
```hcl
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}
```
Este trecho do código gera um **par de chaves SSH** para acesso seguro à instância EC2.  
- **Chave privada** é criada localmente com criptografia RSA de **2048 bits**.
- A **chave pública** é registrada na AWS, permitindo o acesso SSH à instância.

O uso de SSH com chave pública é considerado **mais seguro** do que usar senhas para acessar instâncias na nuvem.

### **4. Criando a VPC (Rede Privada)**  
```hcl
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}
```
Este bloco cria uma **VPC (Virtual Private Cloud)**, que é uma rede isolada dentro da AWS para hospedar os recursos.  
- **`cidr_block 10.0.0.0/16`**: Define o espaço de endereços IP privados da rede, permitindo até **65.536 endereços IP**.  
- **Habilitação de DNS**: Permite que as instâncias dentro da VPC utilizem **nomes de host** em vez de IPs para comunicação interna.

### **5. Criando uma Subnet**  
```hcl
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}
```
Cria uma **sub-rede dentro da VPC** com o bloco **`10.0.1.0/24`**, permitindo **256 endereços IP privados**. Além disso, especifica que essa subnet será criada na **zona de disponibilidade `us-east-1a`**, o que ajuda na **disponibilidade e redundância** dos recursos.

### **6. Criando um Gateway de Internet**  
```hcl
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
}
```
Este bloco cria um **Gateway de Internet**, permitindo que os recursos dentro da VPC se conectem à internet.

### **7. Criando uma Tabela de Rotas**  
```hcl
resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }
}
```
Cria uma **Tabela de Rotas** para direcionar todo o tráfego da VPC para a internet através do **Gateway de Internet**. Isso garante que a instância EC2 tenha acesso à internet.

### **8. Criando um Grupo de Segurança**  
```hcl
resource "aws_security_group" "sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```
Este bloco cria um **Grupo de Segurança** para controlar o acesso à instância EC2.  
- A **porta 22 (SSH)** está aberta para **qualquer IP** (`0.0.0.0/0`), permitindo o acesso remoto.
- A **porta 80 (HTTP)** também está aberta para **qualquer IP** (`0.0.0.0/0`), permitindo o acesso ao servidor web.

---

## **Observações**

### **1. Acesso SSH Aberto para Qualquer IP**
- O código permite que qualquer pessoa acesse a instância EC2 via **SSH (porta 22)**. Isso pode ser um **ponto fraco** se não for bem controlado.
- O ideal seria restringir o acesso à **rede interna da empresa** ou à **VPN**, garantindo que apenas usuários autorizados possam acessar a instância.

### **2. Instância EC2 Sem Configuração Automática**
- Após a criação, a **instância EC2 será um servidor vazio**. Isso significa que, após o provisionamento, a instância não estará configurada para rodar uma aplicação automaticamente.
- Seria interessante adicionar um **script `user_data`** para automatizar a instalação e configuração dos serviços necessários na instância, como um servidor web (por exemplo, Nginx ou Apache).

### **3. IP Público da EC2 Pode Mudar**
- Se a instância EC2 for reiniciada, seu **IP público pode mudar**, o que pode causar problemas no acesso remoto.
- Seria útil associar um **Elastic IP** à instância para garantir que o **IP público da EC2 seja fixo**.

---

# **Tarefa 2**  
# **Modificação e Melhoria do Código Terraform**

Este documento detalha as **melhorias implementadas** no código Terraform, organizadas conforme os requisitos do desafio:  

✅ **Aplicação de melhorias de segurança**: Restringindo acessos e garantindo proteção da infraestrutura.  
✅ **Automação da instalação do Nginx**: Configuração automática da instância EC2 para estar pronta para uso imediatamente.  
✅ **Outras melhorias**: Tornando a região AWS configurável, escolhendo automaticamente uma zona de disponibilidade e buscando a AMI compatível com qualquer região.

---

## **Código Terraform Modificado (`main.tf`)**
```hcl
# Variável para definir a região AWS dinamicamente
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

  # Permite acesso HTTP para qualquer IP (para acessar o Nginx)
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
```

---

# **Descrição Técnica das Melhorias Implementadas**

A seguir, explicamos **o que foi alterado no código, por que isso foi necessário e o resultado esperado**.

## **1. Aplicação de Melhorias de Segurança**
### **1.1 Restringindo Acesso SSH**
- **O que foi alterado?**  
  Antes, o código permitia **acesso SSH aberto para qualquer IP (`0.0.0.0/0`)**. Agora, o acesso SSH **está restrito apenas a IPs da VPN da empresa**.  
- **Por que isso foi necessário?**  
  Isso impede acessos externos indesejados e garante que **apenas usuários autenticados pela VPN** possam acessar a instância EC2.
- **Código alterado:**  
  ```hcl
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.168.100.0/24"]
  }
  ```
- **Resultado esperado:**  
  A instância EC2 só poderá ser acessada por usuários **autorizados dentro da rede da VPN**.

---

## **2. Automação da Instalação do Nginx**
- **O que foi alterado?**  
  Agora, o Terraform **instala e inicia automaticamente o Nginx** assim que a instância EC2 é criada.
- **Por que isso foi necessário?**  
  Isso evita a necessidade de configuração manual após a criação do servidor, tornando o ambiente pronto para uso.
- **Código alterado:**  
  ```hcl
  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install nginx -y
    systemctl start nginx
    systemctl enable nginx
  EOF
  ```
- **Resultado esperado:**  
  Assim que a EC2 for provisionada, o **Nginx estará instalado e rodando automaticamente**, pronto para receber requisições HTTP.

---

## **3. Outras Melhorias**
### **3.1 Tornando a Região AWS Configurável**
Agora, a **região AWS pode ser alterada sem editar o código**, bastando passar um novo valor na linha de comando:
```sh
terraform apply -var="aws_region=sa-east-1"
```
Isso permite flexibilidade para implantar a infraestrutura em qualquer região da AWS.

---

### **3.2 Escolha Automática da Zona de Disponibilidade**
O Terraform agora **seleciona automaticamente uma zona válida para a região escolhida**, evitando falhas ao mudar a localização.

- **Código alterado:**  
  ```hcl
  data "aws_availability_zones" "available" {}

  resource "aws_subnet" "main_subnet" {
    vpc_id            = aws_vpc.main_vpc.id
    cidr_block        = "10.0.1.0/24"
    availability_zone = data.aws_availability_zones.available.names[0]
  }
  ```

---

### **3.3 Seleção Automática da AMI**
Agora, a AMI do Ubuntu **é buscada dinamicamente**, garantindo que sempre exista na região escolhida.

- **Código alterado:**  
  ```hcl
  data "aws_ami" "ubuntu" {
    most_recent = true
    owners      = ["099720109477"]

    filter {
      name   = "name"
      values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    }

    filter {
      name   = "virtualization-type"
      values = ["hvm"]
    }
  }
  ```

---

# **Conclusão**
Agora, a infraestrutura pode ser implantada **em qualquer região AWS**, mantendo segurança, automação e compatibilidade com a VPN.
