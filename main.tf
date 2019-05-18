provider "aws" {
  region = "us-east-1"
}


terraform {
    backend "s3" {
        bucket = "YOU_S3_BUCKET"
        key = "global/terraform.tfstate"
        region = "us-east-1"
        encrypt = true
#        depends_on = "${aws_s3_bucket.terraform_state.bucket}"
    }
}


data "aws_vpc_endpoint" "input" {
  id = "${aws_vpc_endpoint.endpoint_s3.id}"
}

resource "aws_route53_zone" "private" {
  name         = "tradewindmarkets.com."
  
  lifecycle {
    ignore_changes = ["vpc"]
  }
  vpc {
    vpc_id = "vpc-d56cc2af"
  }

}


resource "aws_vpc_endpoint" "endpoint_s3" {
  vpc_id       = "vpc-d56cc2af"
  service_name = "com.amazonaws.us-east-1.s3"
  route_table_ids = ["rtb-85f3c6fa"]
#  subnet_ids      = ["subnet-02128d5e","subnet-0a65f76d","subnet-acf6a2a3","subnet-45069f6b","subnet-57e44569","subnet-158aa85f"]
    policy = <<POLICY
{
    "Statement": [
        {
            "Action": "*",
            "Effect": "Allow",
            "Resource": "*",
            "Principal": "*"
        }
    ]
}
POLICY
}

resource "aws_vpc_endpoint" "endpoint_api" {
  vpc_endpoint_type = "Interface"
  vpc_id       = "vpc-d56cc2af"
  service_name = "com.amazonaws.us-east-1.execute-api"
  subnet_ids      = ["subnet-02128d5e","subnet-0a65f76d","subnet-acf6a2a3","subnet-45069f6b","subnet-57e44569","subnet-158aa85f"]
  security_group_ids = ["${aws_security_group.sg_instance.id}"]
  private_dns_enabled = false
}

resource "aws_vpc_endpoint_route_table_association" "endpoint_associate" {
  route_table_id  = "rtb-85f3c6fa"
  vpc_endpoint_id = "${aws_vpc_endpoint.endpoint_s3.id}"
}

#resource "aws_vpc_endpoint_subnet_association" "subnet_ec2_s3" {
#  vpc_endpoint_id = "${aws_vpc_endpoint.endpoint_s3.id}"
#  subnet_id       = "subnet-02128d5e,subnet-0a65f76d,subnet-acf6a2a3,subnet-45069f6b,subnet-57e44569,subnet-158aa85f"
#}

#resource "aws_route53_zone_association" "associate-private" {
#  zone_id = "${aws_route53_zone.private.zone_id}"
#  vpc_id  = "vpc-d56cc2af"
#}




resource "aws_instance" "nginx" {
  ami           = "ami-009d6802948d06e52"
  instance_type = "t3.micro"
  security_groups = ["${aws_security_group.sg_instance.name}"]
  key_name        = "${var.key_name}"
 
  provisioner "local-exec" {

#    working_dir = "../ansible/"
    command     = "sleep 120; ansible-playbook -i ${aws_instance.nginx.public_ip}, -u ec2-user --private-key ${var.ssh_key} playbook.yml"
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "null_resource" "nginx_conf_change" {
  triggers = {
    file_sha1 = "${sha1(file("templates/nginx/default"))}"
  }
  depends_on = ["aws_eip_association.eip_nginx_instance"]
  provisioner "local-exec" {
    command = "ansible-playbook -i ${var.elastic_ip}, -u ec2-user --private-key ${var.ssh_key} playbook.yml"
  }
}

resource "aws_eip_association" "eip_nginx_instance" {
  instance_id   = "${aws_instance.nginx.id}"
  allocation_id = "eipalloc-0bec3bd6c87bdefff"
}

resource "aws_security_group" "sg_instance" {
    name        = "security_group_instance"

  ingress {
    from_port   = "${var.http_port}"
    to_port     = "${var.http_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = "${var.https_port}"
    to_port     = "${var.https_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = "${var.ssh_port}"
    to_port     = "${var.ssh_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

