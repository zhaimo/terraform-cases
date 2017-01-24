resource "aws_instance" "webvm" {
  ami = "ami-2d39803a"
  instance_type = "t2.micro"
  
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF
  tags {
    Name = "terraform-webvm"
  }
}
