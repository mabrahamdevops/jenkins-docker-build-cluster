variable "jenkins_docker_port" {
    description = "The port Jenkins-Docker build container will use for http access"
    type    = number
    default = 8080
}

variable "alb_name" {
    description = "The name of the ALB"
    type        = string
    default     = "build-server-ALB"
}

variable "alb_security_group_name" {
    description = "The name of the security group for the ALB"
    type        = string
    default     = "build-server-alb-sg"
}