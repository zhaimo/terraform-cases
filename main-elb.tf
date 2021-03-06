provider "aws" {
  region = "us-east-1"
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  default = 8080
}
# --------------------------------------------------------------------------------------------------------------------- 
# GET THE LIST OF AVAILABILITY ZONES IN THE CURRENT REGION 
# ---------------------------------------------------------------------------------------------------------------------
data "aws_availability_zones" "all" {}
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "ec2" {
  name = "terraform-ec2"
  ingress {
    from_port = "${var.server_port}"
    to_port = "${var.server_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 lifecycle {
    create_before_destroy = true
  }
}
resource "aws_security_group" "elb" {
  name = "terraform-elb"
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_launch_configuration" "elbweb" {
  image_id = "ami-2d39803a"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.ec2.id}"]
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "elbweb" {
  launch_configuration = "${aws_launch_configuration.elbweb.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  load_balancers = ["${aws_elb.elbweb.name}"]
  health_check_type = "ELB"

  min_size = 2
  max_size = 3
  tag {
    key = "Name"
    value = "terraform-asg-elbweb"
    propagate_at_launch = true
  }
}
resource "aws_elb" "elbweb" {
  name = "terraform-elbweb"
  security_groups = ["${aws_security_group.elb.id}"]
  availability_zones = ["${data.aws_availability_zones.all.names}"]
 health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:${var.server_port}/"
  }
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "${var.server_port}"
    instance_protocol = "http"
  }
}


output "elb_dns_name" {
  value = "${aws_elb.elbweb.dns_name}"
}