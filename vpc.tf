provider "aws" {
  region = "us-east-1"
}

# Creating VPC vpc.tf
resource "aws_vpc" "project-vpc" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  tags = {
    name = "project-vpc"
  }
}

# create 3 subnet public
resource "aws_subnet" "public_subnets" {
  vpc_id                  = aws_vpc.project-vpc.id
  count                   =  3
  cidr_block              = var.cidr_public_subnets[count.index]
  map_public_ip_on_launch = true
  availability_zone       = var.az[count.index]
  tags = {
    name = "public_subnets(3)"
  }
}

# create 3 subnet private
resource "aws_subnet" "private_subnets" {
  vpc_id            = aws_vpc.project-vpc.id
  count                   =  3
  cidr_block        = var.cidr_private_subnets[count.index]
  availability_zone = var.az[count.index]
  tags = {
    name = "private_subnets(3)"
  }
}

# Creating Internet Gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.project-vpc.id
  tags = {
    name = "ProjectIGW"
  }
}


# Creating Route Table - Attach IGW to Public Subnet 
resource "aws_route_table" "public_subnet_route" {
  vpc_id = aws_vpc.project-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    name = "routeIGW"
  }
}

# Associating Route Table
resource "aws_route_table_association" "rt-public-subnets" {
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_subnet_route.id
  count          = 3
}

# Create Elastic IP for NatGateway 
resource "aws_eip" "ipfornat" {
  vpc = true
  tags = {
    name = "elastic ip for natgw"
  }
}

# NAT gateway to give our private subnets to access to the outside world
resource "aws_nat_gateway" "NGW" {
  allocation_id = aws_eip.ipfornat.id
  subnet_id     = aws_subnet.public_subnets[0].id
   depends_on        = [aws_internet_gateway.igw]
  tags = {
    name = "natgateway"
  }
}

# Creating Route Table ngw - private routes 
resource "aws_route_table" "pr_subnet_route" {
  vpc_id = aws_vpc.project-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.NGW.id
  }
  tags = {
    name = "privateroutetable"
  }
}

# Associating Route Table
resource "aws_route_table_association" "nat-rt-private" {
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.pr_subnet_route.id
  count          = 3
}



#2 sec group.tf
resource "aws_security_group" "secgroups" {
  name   = "secgroups"
  vpc_id = aws_vpc.project-vpc.id
  # Inbound Rules
  # HTTP access from anywhere
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access from anywhere
  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  # Outbound Rules
  # Internet access to anywhere
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

}

## opened 80,443 & 22 ports for the inbound connection and  all the ports  open for the outbound connection


# create key pair  and ec2 instance ec2.tf
resource "aws_key_pair" "forproject" {
  key_name   = "for project"
  public_key = file(var.public_key)
}

# data source
data "aws_ami" "amazon-2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
  owners = ["amazon"]
}


resource "aws_instance" "Wordpress" {
  ami                         = data.aws_ami.amazon-2.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.forproject.key_name
  vpc_security_group_ids      = [aws_security_group.secgroups.id]
  subnet_id                   = aws_subnet.public_subnets[0].id
  associate_public_ip_address = true
  tags = {
    Name = "My Public Instance1 in public subnet1"
  }
  connection {
    type        = "ssh"
    user        = var.instance_username
    private_key = file(var.private_key)
    host        = aws_instance.Wordpress.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y httpd php php-mysqlnd",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
      "sudo amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2",
      "cd /var/www/html",
      " sudo wget https://wordpress.org/latest.tar.gz",
      "sudo tar -xzf latest.tar.gz",
      " sudo cp -R wordpress/* /var/www/html/",
      " sudo chown -R apache:apache /var/www/html/",
      " sudo systemctl restart httpd"
    ]
  }

}


# create alb alb.tf
resource "aws_lb" "external-alb" {
  name                       = "external-alb"
  internal                   = false
  ip_address_type            = "ipv4"
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.secgroups.id]
  subnets                    = [aws_subnet.public_subnets[0].id, aws_subnet.public_subnets[1].id, aws_subnet.public_subnets[2].id]
  enable_deletion_protection = true
  tags = {
    environment = "albforproject"
  }
}

# create load balancer target group
resource "aws_lb_target_group" "target-alb" {
  name        = "target-alb"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.project-vpc.id
  health_check {
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    port                = 80
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = 200
  }
}


# Load balancer listener
resource "aws_lb_listener" "external-alb-listener" {
  load_balancer_arn = aws_lb.external-alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-alb.arn
  }
}

# Target group attachment
resource "aws_lb_target_group_attachment" "tg-attachment" {
  target_group_arn = aws_lb_target_group.target-alb.arn
  target_id        = aws_instance.Wordpress.id
  port             = 80
}

# create a file system
resource "aws_efs_file_system" "efs" {
  creation_token = "my-efs"

  tags = {
    Name = "efs"
  }
}

resource "aws_efs_mount_target" "mount-project" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = aws_subnet.public_subnets[0].id
}


# Launch template Launch template.tf
resource "aws_launch_template" "my_launch_template" {

  name          = "my_launch_template"
  image_id      = data.aws_ami.amazon-2.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.forproject.id
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.secgroups.id]
  }
}

#asg.tf
#ASG with Launch Template 3 public subnet 
resource "aws_autoscaling_group" "Three-tier-asg" {
  name                = "Three-tier-asg"
  desired_capacity    = 1
  max_size            = 99
  min_size            = 1
  health_check_type   = "ELB"
  target_group_arns   = [aws_lb_target_group.target-alb.arn]
  vpc_zone_identifier = [aws_subnet.public_subnets[0].id, aws_subnet.public_subnets[1].id, aws_subnet.public_subnets[2].id]
  launch_template {
    id      = aws_launch_template.my_launch_template.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale_up"
  policy_type            = "SimpleScaling"
  autoscaling_group_name = aws_autoscaling_group.Three-tier-asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "1"
  cooldown               = "300"
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "asg-scale-down"
  autoscaling_group_name = aws_autoscaling_group.Three-tier-asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "-1"
  cooldown               = "300"
  policy_type            = "SimpleScaling"
}