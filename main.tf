data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "tls_private_key" "app_server" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "app_server_key" {
  key_name   = var.keypair_name
  public_key = tls_private_key.app_server.public_key_openssh
}

resource "local_file" "server_prvt_key" {
  sensitive_content = tls_private_key.app_server.private_key_pem
  filename          = var.private_key_pem_name
  file_permission = "0777"
}

resource "aws_s3_bucket" "keys" {
  count = var.create_s3_bucket ? 1 : 0
  bucket = var.s3_name
}

resource "aws_s3_bucket_object" "bastion_private_key" {
  count = var.create_s3_bucket ? 1 : 0
  depends_on = [
    local_file.server_prvt_key
  ]

  bucket = aws_s3_bucket.keys[0].id
  key    = basename(var.private_key_pem_name)
  source = var.private_key_pem_name
}

resource "aws_security_group" "app_sg" {
  name        = "App server security Group"
  vpc_id      = data.aws_vpc.default.id
# Inbound Rules
  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr
  }
  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
# Outbound Rules
  # Internet access to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = var.securitygroup_name
  }
}

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.image_id
  instance_type = var.instance_type
  subnet_id = tolist(data.aws_subnet_ids.all.ids)[0]
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  associate_public_ip_address = true
  ebs_optimized = true
  key_name = aws_key_pair.app_server_key.key_name
  user_data_base64 = base64encode(local.user_data)

  root_block_device {
    volume_type = "gp2"
    volume_size = 20
  }

  provisioner "file" {
    source = "./deploy.yaml"
    destination = "/tmp/deploy.yaml"

    connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = tls_private_key.app_server.private_key_pem
    host     = coalesce(self.public_ip, self.private_ip)
  }
  }

  tags = {
    Name = var.app_name
  }
}