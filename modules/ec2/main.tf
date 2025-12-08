resource "aws_launch_template" "app" {
  name_prefix   = "app-template-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  user_data     = base64encode(var.user_data)

  network_interfaces {
    security_groups = var.security_group_ids
  }

  dynamic "iam_instance_profile" {
    for_each = var.instance_profile != "" ? [1] : []
    content {
      name = var.instance_profile
      # or use arn = var.instance_profile if pass an ARN
    }
  }
}

resource "aws_instance" "app" {
  count                       = var.instance_count
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = element(var.subnet_ids, count.index % length(var.subnet_ids))
  vpc_security_group_ids      = var.security_group_ids
  user_data                   = var.user_data

  iam_instance_profile = var.instance_profile != "" ? var.instance_profile : null

  tags = {
    Name = "app-instance-${count.index}"
  }
}