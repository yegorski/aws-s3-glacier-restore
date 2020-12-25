resource "aws_security_group" "ec2" {
  name        = "${var.app_name}-ec2"
  description = "Allows ingress from SSH from specified IP address and egress to the internet."
  vpc_id      = "${var.vpc_id}"

  ingress {
    protocol  = "TCP"
    from_port = "22"
    to_port   = "22"

    cidr_blocks = [
      "10.0.0.0/8",
      "${var.ssh_ip}/32",
    ]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${var.tags}"
}
