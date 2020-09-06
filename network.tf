resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "public" {
  count             = var.az_count
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = aws_vpc.main.id
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

### Compute

resource "aws_autoscaling_group" "main" {
  name                 = "${var.app_name}_asg"
  vpc_zone_identifier  = aws_subnet.public.*.id
  min_size             = var.asg_min
  max_size             = var.asg_max
  desired_capacity     = var.asg_desired
  launch_configuration = aws_launch_configuration.main.name
}

data "template_file" "cloud_config" {
  template = file("${path.module}/cloud-config.yml")

  vars = {
    aws_region         = var.aws_region
    ecs_cluster_name   = aws_ecs_cluster.app.name
    ecs_log_level      = "info"
    ecs_agent_version  = "latest"
    ecs_log_group_name = aws_cloudwatch_log_group.ecs.name
  }
}

data "aws_ami" "stable_coreos" {
  most_recent = true

  filter {
    name   = "description"
    values = ["CoreOS Container Linux stable *"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["595879546273"] # CoreOS
}

resource "aws_launch_configuration" "main" {
  security_groups = [
    aws_security_group.instance_sg.id,
  ]

  key_name                    = var.key_name
  image_id                    = data.aws_ami.stable_coreos.id
  instance_type               = var.instance_type
  iam_instance_profile        = aws_iam_instance_profile.app.name
  user_data                   = data.template_file.cloud_config.rendered
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
}

### Security

resource "aws_security_group" "lb_sg" {
  description = "controls access to the application ELB"

  vpc_id = aws_vpc.main.id
  name   = "${var.app_name}_lb_sg"

  ingress {
    protocol  = "tcp"
    from_port = 80
    to_port   = 80
    cidr_blocks = [
      var.admin_cidr_ingress,
    ]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}

resource "aws_security_group" "instance_sg" {
  description = "controls direct access to application instances"
  vpc_id      = aws_vpc.main.id
  name        = "${var.app_name}_ec2_sg"

  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22

    cidr_blocks = [
      var.admin_cidr_ingress,
    ]
  }

  ingress {
    protocol  = "tcp"
    from_port = 32768
    to_port   = 61000

    security_groups = [
      aws_security_group.lb_sg.id,
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## ECS

resource "aws_ecs_cluster" "app" {
  name = "${var.app_name}_cluster"
}

data "template_file" "task_definition" {
  template = file("${path.module}/task-definition.json")

  vars = {
    image_url        = var.image_url
    container_name   = "${var.app_name}_container"
    container_port   = var.container_port
    log_group_region = var.aws_region
    log_group_name   = aws_cloudwatch_log_group.app.name
  }
}

resource "aws_ecs_task_definition" "app" {
  family                = "${var.app_name}_td"
  container_definitions = data.template_file.task_definition.rendered
}

resource "aws_ecs_service" "app" {
  name            = "${var.app_name}_service"
  cluster         = aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.service_desired_count
  iam_role        = aws_iam_role.ecs_service.name

  load_balancer {
    target_group_arn = aws_alb_target_group.test.id
    container_name   = "${var.app_name}_container"
    container_port   = var.container_port
  }

  depends_on = [
    aws_iam_role_policy.ecs_service,
    aws_alb_listener.front_end,
  ]
}

## IAM

resource "aws_iam_role" "ecs_service" {
  name = "${var.app_name}_service_role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ecs_service" {
  name = "${var.app_name}_service_role_policy"
  role = aws_iam_role.ecs_service.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.app_name}_instance_profile"
  role = aws_iam_role.app_instance.name
}

resource "aws_iam_role" "app_instance" {
  name = "${var.app_name}_instance_profile_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "template_file" "instance_profile" {
  template = file("${path.module}/instance-profile-policy.json")

  vars = {
    app_log_group_arn = aws_cloudwatch_log_group.app.arn
    ecs_log_group_arn = aws_cloudwatch_log_group.ecs.arn
  }
}

resource "aws_iam_role_policy" "instance" {
  name   = "${var.app_name}_instance_profile_role_policy"
  role   = aws_iam_role.app_instance.name
  policy = data.template_file.instance_profile.rendered
}

## ALB

resource "aws_alb_target_group" "test" {
  name     = "${var.app_name}_alb_tg"
  port     = var.alb_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_alb" "main" {
  name            = "${var.app_name}_alb"
  subnets         = aws_subnet.public.*.id
  security_groups = [aws_security_group.lb_sg.id]
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_alb.main.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.test.id
    type             = "forward"
  }
}

## CloudWatch Logs

resource "aws_cloudwatch_log_group" "ecs" {
  name = "${var.app_name}/ecs-agent"
}

resource "aws_cloudwatch_log_group" "app" {
  name = "${var.app_name}/api"
}
