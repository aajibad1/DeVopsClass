provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "prod-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = "true"        #gives you an internal domain name
  enable_dns_hostnames = "true"        #gives you an internal host name
  enable_classiclink   = "false"
  instance_tenancy     = "default"

  tags {
    Name = "prod-vpc"
  }
}

resource "aws_subnet" "prod-subnet-public-1" {
  vpc_id                  = "${aws_vpc.prod-vpc.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true"                   //it makes this a public subnet

  tags {
    Name = "prod-subnet-public-1"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = "${aws_vpc.prod-vpc.id}"
  cidr_block = "10.0.3.0/24"

  tags = {
    Name = "private_subnet"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.prod-vpc.id}"

  tags = {
    Name = "main"
  }
}

# /*
#   NAT Instance
# */
# resource "aws_security_group" "nat" {
#     name = "vpc_nat"
#     description = "Allow traffic to pass from the private subnet to the internet"
#
#     ingress {
#         from_port = 80
#         to_port = 80
#         protocol = "tcp"
#         cidr_blocks = ["${var.private_subnet_cidr}"]
#     }
#     ingress {
#         from_port = 443
#         to_port = 443
#         protocol = "tcp"
#         cidr_blocks = ["${var.private_subnet_cidr}"]
#     }
#     ingress {
#         from_port = 22
#         to_port = 22
#         protocol = "tcp"
#         cidr_blocks = ["0.0.0.0/0"]
#     }
#     ingress {
#         from_port = -1
#         to_port = -1
#         protocol = "icmp"
#         cidr_blocks = ["0.0.0.0/0"]
#     }
#
#     egress {
#         from_port = 80
#         to_port = 80
#         protocol = "tcp"
#         cidr_blocks = ["0.0.0.0/0"]
#     }
#     egress {
#         from_port = 443
#         to_port = 443
#         protocol = "tcp"
#         cidr_blocks = ["0.0.0.0/0"]
#     }
#     egress {
#         from_port = 22
#         to_port = 22
#         protocol = "tcp"
#         cidr_blocks = ["${var.vpc_cidr}"]
#     }
#     egress {
#         from_port = -1
#         to_port = -1
#         protocol = "icmp"
#         cidr_blocks = ["0.0.0.0/0"]
#     }
#
#     vpc_id = "${aws_vpc.default.id}"
#
#     tags {
#         Name = "NATSG"
#     }
# }
#
# resource "aws_instance" "nat" {
#     ami = "ami-30913f47" # this is a special ami preconfigured to do NAT
#     availability_zone = "eu-west-1a"
#     instance_type = "m1.small"
#     key_name = "${var.aws_key_name}"
#     vpc_security_group_ids = ["${aws_security_group.nat.id}"]
#     subnet_id = "${aws_subnet.eu-west-1a-public.id}"
#     associate_public_ip_address = true
#     source_dest_check = false
#
#     tags {
#         Name = "VPC NAT"
#     }
# }
#
# resource "aws_eip" "nat" {
#     instance = "${aws_instance.nat.id}"
#     vpc = true
# }

resource "aws_route_table" "public_route" {
  vpc_id = "${aws_vpc.prod-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name = "main"
  }
}

resource "aws_route_table_association" "public_route_table" {
  subnet_id      = "${aws_subnet.prod-subnet-public-1.id}"
  route_table_id = "${aws_route_table.public_route.id}"
}

resource "aws_security_group" "ssh-allowed" {
  vpc_id = "${aws_vpc.prod-vpc.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    // This means, all ip address are allowed to ssh !
    // Do not do it in the production.
    // Put your office or home address in it!
    cidr_blocks = ["0.0.0.0/0"]
  }

  //If you do not add this rule, you can not reach the NGIX
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "ssh-allowed"
  }
}

# resource "aws_security_group" "allow_https" {
#   name        = "allow_https"
#   description = "Allow https inbound traffic"
#   vpc_id      = "${aws_vpc.prod-vpc.id}"
#
#   ingress {
#     description = "http from VPC"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   tags = {
#     Name = "allow_https"
#   }
# }

resource "aws_instance" "jenkins" {
  ami           = "ami-07ebfd5b3428b6f4d"
  instance_type = "t2.micro"
  subnet_id     = "${aws_subnet.prod-subnet-public-1.id}"
  key_name      = "newkey"

  #add associate_public_ip_address
  associate_public_ip_address = true

  #add source check
  source_dest_check      = false
  vpc_security_group_ids = ["${aws_security_group.ssh-allowed.id}"]

  tags = {
    Name = "jenkins"
  }
}

# resource "aws_eip" "web-1" {
#   instance = "${aws_instance.jenkins.id}"
#   vpc      = true
# }

resource "aws_instance" "tomcat" {
  ami           = "ami-0c322300a1dd5dc79"
  instance_type = "t2.micro"
  subnet_id     = "${aws_subnet.prod-subnet-public-1.id}"
  key_name      = "newkey"

  #add associate_public_ip_address
  associate_public_ip_address = true

  #add source check
  source_dest_check      = false
  vpc_security_group_ids = ["${aws_security_group.ssh-allowed.id}"]

  tags = {
    Name = "tomcat"
  }
}
