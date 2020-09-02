data "aws_iam_role" "ecs_assume_role_policy" {
  name               = "${var.app_name}_ecs_assume_role"
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.app_name}_ecs_task_execution"
  assume_role_policy = data.aws_iam_role.ecs_assume_role_policy
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.app_name}_ecs_task"
  assume_role_policy = data.aws_iam_role.ecs_assume_role_policy
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "task_s3" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
