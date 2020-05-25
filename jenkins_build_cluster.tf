terraform {
    required_version = ">= 0.12, <0.13"
}
# https://www.terraform.io/docs/providers/aws/index.html
provider "aws" {
    region = "us-east-2"
    
    # Allow any 2.x version of the aws provider
    version = "~> 2.0"
}

#Deploying Jenkins and Docker to a Linux vm in a Docker container with autoscaling
# https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
resource "aws_launch_configuration" "jenkinsdocker-asg" {
    image_id        = "ami-097834fcb3081f51a"
    instance_type   = "t2.micro"
    security_groups = [aws_security_group.alb.id]

# Simple smoke test for ASG creation. Go to https://dns_name:8080 or use (where dns_name is the DNS of the load balancer)  )
# curl from shell
    user_data = <<-EOF
        #!/bin/bash
        echo "ASG is running succesfully!" > index.html
        nohup busybox httpd -f -p &{var.jenkins_docker_port} &
        EOF

    # Required when using a launch configuration with an auto scaling group
    # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
    lifecycle {
        create_before_destroy = true
    }
}

# https://www.terraform.io/docs/providers/aws/r/autoscaling_group.html
resource "aws_autoscaling_group" "buiLd-server-asg" {
    launch_configuration    = aws_launch_configuration.jenkinsdocker-asg.name
    vpc_zone_identifier     = data.aws_subnet_ids.default.ids

    target_group_arns       = [aws_lb_target_group.asg.arn]
    health_check_type       = "ELB"                         
    # Use type ELB rather than EC2. ELB uses the target group health check rather than AWS instance health check
    
    min_size = 2
    max_size = 10

    tag {
        key                 = "Name"
        value               = "build-asg"
        propagate_at_launch = true
    }
}

# AWS Load balancer for JenkinsDocker-ASG for high availability
# https://www.terraform.io/docs/providers/aws/r/lb.html
resource "aws_lb" "build-LB" {
    
    name                = var.alb_name

    load_balancer_type  = "application"
    subnets             = data.aws_subnet_ids.default.ids
    security_groups     = [aws_security_group.alb.id]
 }

# https://www.terraform.io/docs/providers/aws/r/lb_listener.html
resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.build-LB.arn
    port        = 80
    protocol    = "HTTP"

    # By default, if there are LB issues, return a basic Error 404 not found page when requests don't Match aws listener rules
    default_action {
        type = "fixed-response"

        fixed_response {
            content_type = "text/plain"
            message_body = "Error 404: page not found"
            status_code = 404
        }
    }
}

# https://www.terraform.io/docs/providers/aws/r/lb_listener_rule.html
resource "aws_lb_listener_rule" "asg" {
    listener_arn    = aws_lb_listener.http.arn
    priority        = 100

    # This following configuration sends listener requests that match any path to the BuiLd-server-ASG target group
    condition {
        path_pattern {
            values  = ["*"]
        }
    }

    action {
        type                = "forward"
        target_group_arn    = aws_lb_target_group.asg.arn
    }
}

# This is the load balancing group for the build server auto scaling group
# https://www.terraform.io/docs/providers/aws/r/lb_target_group.html
resource "aws_lb_target_group" "asg" {
    name        = "build-server-ASG-TG"
    port        = var.jenkins_docker_port
    protocol    = "HTTP"
    vpc_id      = data.aws_vpc.default.id

# The build-server-ASG-TG will perform health checks on the instances in the ASG with periodic HTTP requests
# The matcher filter will look for a 200 ok response
health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold    = 2
    unhealthy_threshold = 2
    }
}

# https://www.terraform.io/docs/providers/aws/r/security_group.html
resource "aws_security_group" "alb" {
    name =  var.alb_security_group_name

    # Allow inbound HTTP requests
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = 80
        cidr_blocks = ["0.0.0.0/0"]
    }

    # Allow all outbound requests
    egress {
        from_port   = 0
        to_port     = 0 
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# https://www.terraform.io/docs/providers/aws/d/vpc.html
data "aws_vpc" "default" {
    default = true
}

# https://www.terraform.io/docs/providers/aws/d/subnet_ids.html
data "aws_subnet_ids" "default" {
    vpc_id = data.aws_vpc.default.id
}