aws_region    = "us-east-1"
project_name  = "terraform-aws-3tier-app"
environment   = "dev"
instance_type = "t3.micro"
key_name = "your-ec2-keypair-name"   # an existing EC2 key pair in your target region
my_ip    = "x.x.x.x/32"               # your public IP — find it with: curl -s https://checkip.amazonaws.com