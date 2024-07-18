output "linux2_ami_id" {
  value = data.aws_ami.ubuntu.id
}

# output "gitlab_amiid" {
#   value = data.aws_ami.gitlab_ami.image_id
# }
