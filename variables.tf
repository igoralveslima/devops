variable "app_name" {
    description = "Name of the application to prefix all resources with"
}

variable "key_name" {
  description = "Name of AWS key pair"
}

variable "admin_cidr_ingress" {
  description = "CIDR to allow tcp/22 ingress to EC2 instance"
}

variable "container_port" {
    description = "Port that application container listens on"
}

variable "alb_port" {
    description = "Port that alb listens on"
}

variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "us-east-1"
}

variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "2"
}

variable "instance_type" {
  default     = "t2.small"
  description = "AWS EC2 instance type"
}

variable "asg_min" {
  description = "Min numbers of servers in ASG"
  default     = "1"
}

variable "asg_max" {
  description = "Max numbers of servers in ASG"
  default     = "2"
}

variable "asg_desired" {
  description = "Desired numbers of servers in ASG"
  default     = "1"
}

variable "service_desired_count" {
  description = "Desired numbers of tasks in the ecs service"
  default     = "1"
}
