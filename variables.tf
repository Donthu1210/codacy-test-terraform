variable "keypair_name" {
  type = string 
  default = "test-key"
}

variable "private_key_pem_name" {
  type = string
  default = "test-key.pem"
}

variable "create_s3_bucket" {
  type = bool
  default = false
}

variable "s3_name" {
  type = string
  default = "ssh-keys"
}

variable "securitygroup_name" {
  type= string
  default = "app-sg"
}

variable "ingress_cidr" {
  type = list
  default = ["0.0.0.0/0"]
}

variable "app_name" {
  type = string
  default = "Appserver"
}

# variable "ec2_instance_name" {
#   type = string
#   default = ""
# }

variable "instance_type" {
  type = string 
  default = "t3.medium"
}

locals {
  user_data = <<EOF
#!/bin/bash
sudo su - root
sudo apt update -y
sudo apt install -y ansible
sudo echo "localhost" >> /etc/ansible/hosts
sudo ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa <<<y >/dev/null 2>&1
sudo  cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
EOF
}