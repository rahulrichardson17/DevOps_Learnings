#--------------------------------------#
#Scenario Questions
#--------------------------------------#
#--------------------------------------#


# Create an Ec2 Instance
#--------------------------------------#
terraform {
  required_version = "~> 1.15"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-south-2"
}

resource "aws_instance" "ec2" {
  ami = "ami-0abcd2342342"
  instance_type = "t3.micro"
  tags = {
    Name = "test-server"
  }
}


# Create an Security Group
#--------------------------------------#
terraform {
  required_version = "~> 1.15"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-south-2"
}

#--- Allow all public traffic

#resource "<resource_type>" "<local_name>"
resource "aws_security_group" "security_group" {
  name = "instance_security_group"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

#---If you want only HTTPS inbound, no SSH
#--Allow users to access my application over HTTPS and allow EC2 to download updates

resource "aws_security_group" "security_group" {
  name = "instance_security_group"

  #Incoming traffic
  ingress {
    from_port = 443
    to_port   = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Dns
  egress {
    from_port = 53
    to_port   = 53
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS downloads
  egress {
    from_port = 443
    to_port   = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#-- Allow incoming traffic only from specific office IP ranges
resource "aws_security_group" "security_group" {
  name = "instance_security_group"

  #Incoming traffic
  ingress {
    from_port = 443
    to_port   = 443
    protocol = "tcp"
    cidr_blocks = [
      "203.0.113.10/32",
      "198.51.100.0/24"
    ]
  }

  #Dns
  egress {
    from_port = 53
    to_port   = 53
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS downloads
  egress {
    from_port = 443
    to_port   = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#--use dynamic block
resource "aws_security_group" "security_group" {
  name = "instance_security_group"
  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = [
      "203.0.113.10/32",
      "198.51.100.0/24"
    ]
  }

  dynamic "egress" {
    for_each = [
      {
        from_port = 53
        to_port   = 53
        protocol  = "udp"
        cidr      = ["0.0.0.0/0"]
      },
      {
        from_port = 443
        to_port   = 443
        protocol  = "tcp"
        cidr      = ["0.0.0.0/0"]
      }
    ]

    content {
      from_port = egress.value.from_port
      to_port   = egress.value.to_port
      protocol  = egress.value.protocol

      cidr_blocks = egress.value.cidr
    }
  }
}

#--Prod way 
variable "egress_rules" {

  type = list(object({
    port = number
    protocol = string
    cidr_blocks = list(string)

  }))

  default = [
    {
      port     = 53
      protocol = "udp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port     = 443
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

variable "ingress_rule" {

  type = list(object({
    port = number
    protocol = string
    cidr_block = list(string)
  }))

  default = [ 
    {
      port = 443
      protocol = "tcp"
      cidr_block = [ "0.0.0.0/0" ]
    } 
  ]
  
}

# egress_rules = [
#   {
#     port     = 53
#     protocol = "udp"
#     cidr_blocks = ["0.0.0.0/0"]
#   },
#   {
#     port     = 443
#     protocol = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# ]

# ingress_rule = [
#   {
#     port     = 443
#     protocol = "tcp"
#     cidr_block = [
#       "203.0.113.10/32",
#       "198.51.100.0/24"
#     ]

#   }
# ]

resource "aws_security_group" "security_group" {
  name = "instance_security_group"

  dynamic "ingress" {

    for_each = var.ingress_rule
    content {
      from_port = ingress.value.from_port
      to_port = ingress.value.to_port
      protocol  = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_block

    }
  }
  
  dynamic "egress" {
    for_each = var.egress_rules
    content {
      from_port = egress.value.port
      to_port   = egress.value.port
      protocol  = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }
}

#---Create a SG and attach it to the ec2
resource "aws_security_group" "security_group" {
  name = "instance_security_group"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {

  ami           = "ami-xxxx"
  instance_type = "t3.micro"

  subnet_id = aws_subnet.public.id

  vpc_security_group_ids = [
    aws_security_group.security_group.id
  ]
}
#This attaches the SG to the EC2 instance's ENI.


#--Create s3 bucket and enable versioning
resource "aws_s3_bucket" "bucket" {
  bucket = "test-bkt-0221"
  tags = {
    owner = "rahul"
    environment = "dev"
  }
  force_destroy = false # if true delete objects first then delete the bucket.
  object_lock_enabled = true # user can't delete/modifiy the objects
}
resource "aws_s3_bucket_versioning" "bucket" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls = true #Stop users creating public ACLs
  block_public_policy = true #Stop policies allowing everyone
  ignore_public_acls = true #Ignore public ACL permissions
  restrict_public_buckets = true #Restrict public access to bucket

}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "bucket" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
#BucketOwnerEnforced disables ACLs and ensures that the S3 bucket owner owns all objects uploaded to the bucket. It removes object ownership conflicts between different AWS accounts and is the recommended setting for modern S3 security.

#----- Create 3 Ec2's and access second one --------
resource "aws_instance" "ec2" {
  count = 3
  ami = "ami-02344534"
  instance_type = "t3-micro"
}
output "second_instance_ip" {
  value = aws_instance.ec2.id
}
output "all_instance_public_ip" {
  value = aws_instance.ec2[*].public_ip
}

# using for_each
variable "instance_name" {
  type = list(string)
}
# instance_name = [
#   "web",
#   "api",
#   "database"
# ]
resource "aws_instance" "ec2" {
  for_each = toset(var.instance_name)
  ami = "ami-02344534"
  instance_type = "t3-micro"
  tags = {
    Name = each.value
  }
}


# -- Use the most latest ami
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name = "Ubuntu Server 26.04 LTS (HVM"
    values = ["ami-0b6d9d3d33ba97d99"]
  }
  filter {
    name = "architecture"
    values = ["x86-64"]
  }
}
#ami = data.aws_ami.amazon_linux.id

data "aws_ami" "amazon_ubuntu" {
  most_recent = true
  owners = ["099720109477"]

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/*"]
  }

  filter {
    name = "architecture"
    values = ["x86_64"]
  }
}


#-Create Iam role
  resource "aws_iam_role" "ec2_role" {
    name = "ec2-role"
    assume_role_policy = jsonencode(
      {
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Principal = {
            Service = "ec2.amazonaws.com"
          }
          Action = "sts:AssumeRole"
        }]
      }
    )
  }

# lambda layer
resource "aws_lambda_layer_version" "this" {
  layer_name = "python-lambda-layers"
  s3_bucket = "lambda-layers"
  s3_key = "layers/packages.zip"
  compatible_runtimes = ["python3.12"]
}
# now tf will create the arn and that can be used in the lambda.

# create the lambda log group
resource "aws_cloudwatch_log_group" "this" {
  name = "/aws/lambda/notification-lambda"
  retention_in_days = 30
}

# create iam role for lambda to use the bucket
resource "aws_iam_role" "this" {
  name = "notification-role"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Principal = {
            Service = "lambda.amazonaws.com"
          }
          Action = "sts:AssumeRole"
        }
      ]
    }
  )
}

# create policy to the lambda , it needs to read it s3 bucket
resource "aws_iam_policy" "this" {
  name = "notification-s3-read"
  policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:ListBucket"
          ]
          Resource = [
            "arn:aws:s3:::lambda-layers",
            "arn:aws:s3:::lambda-layers/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:ListBucket"
          ]
          Resource = [
            "arn:aws:s3:::notification-bucket",
            "arn:aws:s3:::notification-bucket/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "*"
        }
      ]
    }
  )
}

#attach the policy to the role
resource "aws_iam_role_policy_attachment" "this" {
  role = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

# create lambda
resource "aws_lambda_function" "this" {
  function_name = "notification-lambda"
  runtime = "python3.12"
  handler = "lambda_function.lambda_handler"
  role = aws_iam_role.this.arn
  memory_size = 512 # min=128mb max=10gb
  timeout = 900  # min=1 max=900
  reserved_concurrent_executions = 10
  layers = [
    aws_lambda_layer_version.this.arn
  ] # max 5 layers
  depends_on = [ 
    aws_cloudwatch_log_group.this
   ]
  s3_bucket = "notification-bucket"
  s3_key = "notification/v1.zip"
}







