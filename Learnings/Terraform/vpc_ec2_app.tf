provider "aws" {
  region = "ap-south-2"
}

# create a vpc
resource "aws_vpc" "vpc" {
  cidr_block = ["10.0.0.0/16"]
  tags = {
    Name = "prod-vpc"
  }
  enable_dns_support = true # When enabled resources inside the vpc can resolve dns names.
  enable_dns_hostnames = true # allow aws to assign dns names to resources inside the vpc. 
}

# create a public subnet
resource "aws_subnet" "public_sn" {
  vpc_id = aws_vpc.vpc.id

  cidr_block = ["10.0.1.0/24"]
  availability_zone = "ap-south-2a"
  map_public_ip_on_launch = true  #Whenever a new EC2 instance is launched into this subnet, automatically assign it a public IPv4 address.

  tags = {
    Name = "public-subnet"
  }
}

# create a private subnet
resource "aws_subnet" "private_sn" {
  vpc_id = aws_vpc.vpc.id

  cidr_block = ["10.0.2.0/24"]
  availability_zone = "ap-south-2b"
  tags = {
    Name = "private-subnet"
  }
}

# create internet gate way
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id
    tags = {
      Name = "vpc-igw"
    }
}

# create public route tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

# associate public route table to public subnet
resource "aws_route_table_association" "public-rt-ass" {
  route_table_id = aws_route_table.public_rt.id
  subnet_id = aws_subnet.public_sn.id
}

# create elastic ip for nat gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "nat-eip"
  }
}

# create nat gate way
resource "aws_nat_gateway" "ntgw" {
    allocation_id = aws_eip.nat_eip.id
    subnet_id = aws_subnet.public_sn.id
    tags = {
      Name = "nat-gateway"
    }
    depends_on = [ aws_internet_gateway.igw ]
}

# private route table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ntgw.id
  }
  tags = {
    Name = "prv-route-table"
  }
}

# assocaite private subnet
resource "aws_route_table_association" "private_ass" {
  subnet_id = aws_subnet.private_sn.id
  route_table_id = aws_route_table.private_rt.id
}

# create sg for private ec2
resource "aws_security_group" "aws_private_sg" {
    tags = {
      Name = "sg-private-ec2"
    }
    name = "sg-private-ec2"
    vpc_id = aws_vpc.vpc.id

    #allows users from internet
    ingress {
        from_port=5000
        to_port=5000
        protocol="tcp"
        security_groups = [aws_security_group.alb_sg.id]
        # cidr_blocks = ["10.23.4.0/24"]
    }

    #Allow https method
    egress {
        from_port=443
        to_port=443
        protocol="tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    #Dns methods
    egress {
        from_port = 53
        to_port = 53
        protocol = "udp"
        cidr_blocks =  ["0.0.0.0/0"]
    }
}

# create ec2
resource "aws_instance" "ec2" {
  tags = {
    Name = "ec2-instance"
  }
  ami = "ami-22222222"
  instance_type = "t3-micro"
  subnet_id = aws_subnet.private_sn.id
  vpc_security_group_ids = [aws_security_group.aws_private_sg.id]
}

# create an security group for alb
resource "aws_security_group" "alb_sg" {
  name = "sg-for-alb"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "sg-for-alb"
  }
}

# create alb 
resource "aws_alb" "alb" {
  name = "vpc-alb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_sg.id]

  subnets = [aws_subnet.public_sn.id]
  tags = {
    Name = "vpc-alb"
  }
}

# create target group
resource "aws_lb_target_group" "app_lb_tgtgrp" {
  name = "lb-tgt-grp"
  port = 443
  protocol = "HTTPS"
  vpc_id = aws_vpc.vpc.id

  health_check {
    path = "/"
    protocol = "HTTPS"
  }
}

# attach ec2 to target group
resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app_lb_tgtgrp.arn
  target_id = aws_instance.ec2.id
  port = 443
}

#----------------------------------------#
#IAM

#create and IAM group
resource "aws_iam_group" "iam_grp" {
  name = "dev-grp"
}

# create s3 read only policy
resource "aws_iam_policy" "s3_read_policy" {
  name = "s3-read-only"
  policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:ListBucket",
            "s3:GetObject"
          ]
        }
      ]
      Resource = [
        "arn:aws:s3:::test-bkt", #to see the bucket
        "arn:aws:s3:::test-bkt/*", #because objects are inside the bucket to list those.
      ]
    }
  )
}

#attach policy to group
resource "aws_iam_group_policy_attachment" "dev-s3_read" {
  group = aws_iam_group.iam_grp.name
  policy_arn = aws_iam_policy.s3_read_policy.arn
}

# attach user to the group
resource "aws_iam_user_group_membership" "attach_user" {
  user = "rahul"
  groups = [
    aws_iam_group.iam_grp.name
  ]
}


#------------------Lambda----------------#
#create s3 bucket
resource "aws_s3_bucket" "aws_s3_bucket" {
  bucket = "lambda-file"
  tags = {
    Name = "lambda-file"
  }
}

#create lambda execution role
resource "aws_iam_role" "lamb_ex" {
  name = "lambda-s3-execution-role"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Principal = {
            Service = "lambda.amazonaws.com"
          }
          Action = "sts.AssumeRole"
        }
      ]
    }
  )
}

#allow lambda to write logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role = aws_iam_role.lamb_ex.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# create s3 read/write policy
resource "aws_iam_policy" "lambda_s3_Read" {
  name = "lambda-s3-rw-logs"
  policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:ListBucket"
          ]
          Resource = [
            aws_s3_bucket.aws_s3_bucket.arn,
            "${aws_s3_bucket.aws_s3_bucket.arn}/*"
          ]
        }
      ]
    }
  )
}

# attach s3 r/w policy to the lambda role
resource "aws_iam_policy_attachment" "lambd_role_att" {
  name = "attach-role"
  policy_arn = aws_iam_policy.lambda_s3_Read.arn
}

resource "aws_lambda_function" "lambda_func" {
  function_name = "s3-file-upload-lambda"
  role = aws_iam_role.lamb_ex.arn
  runtime = "python3.12"
  handler = "lambda_handler"
  filename = "lambda.zip"
}


terraform {
  backend "s3" {
    bucket = "value"
    key = "value"
    region = "value"
    encrypt = true
    dynamodb_table = "tf-locks"
  }
}

terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "asndjkasnd"

    workspaces {
      name = "naskjdbaskjbndkj"
    }
  }
}