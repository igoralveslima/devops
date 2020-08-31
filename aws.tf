provider "aws" {
  version = "~> 3.4.0"
  region  = "us-east-1"
}

data "aws_iam_policy_document" "allow_account_user_with_mfa" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::368518502115:root"]
    }

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

data "aws_iam_policy_document" "full_admin_access" {
  statement {
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "assume_admin_role" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.admin.arn]
  }
}

resource "aws_iam_role" "admin" {
  name                 = "admin"
  path                 = "/"
  max_session_duration = 43200
  assume_role_policy   = data.aws_iam_policy_document.allow_account_user_with_mfa.json
}

resource "aws_iam_role_policy" "full_admin_access" {
  name   = "full_admin_access"
  role   = aws_iam_role.admin.id
  policy = data.aws_iam_policy_document.full_admin_access.json
}

resource "aws_iam_policy" "assume_admin_role" {
  name        = "assume_admin_role"
  description = "Allows IAM user to assume admin role"
  policy      = data.aws_iam_policy_document.assume_admin_role.json
}

resource "aws_iam_group" "admin" {
  name = "admin"
}

resource "aws_iam_user" "ilima" {
  name = "ilima"
}

resource "aws_iam_group_membership" "admin" {
  name       = "admin"
  group      = "admin"
  users      = ["ilima"]
  depends_on = [aws_iam_user.ilima]
}

resource "aws_iam_group_policy_attachment" "admin" {
  group      = "admin"
  policy_arn = aws_iam_policy.assume_admin_role.arn
}
