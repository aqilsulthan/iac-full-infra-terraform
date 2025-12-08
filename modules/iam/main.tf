resource "aws_iam_role" "app_role" {
  name = "app-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "secret_policy" {
  name   = "app-secret-read-policy"
  policy = file("${path.module}/policy.json")
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.secret_policy.arn
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "app-instance-profile"
  role = aws_iam_role.app_role.name
}