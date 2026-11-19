terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1" # Change to match your lab/AWS region
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_security_group" "ec2_monitoring_sg" {
  name        = "project3-ec2-monitoring-sg"
  description = "No inbound SSH/RDP ports; outbound access for CloudWatch metrics and packages"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "monitored_ec2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.ec2_monitoring_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              END=$((SECONDS+300))
              while [ $SECONDS -lt $END ]; do
                yes > /dev/null &
              done
              wait
              EOF

  user_data_replace_on_change = true

  tags = {
    Name = "project3-monitored-instance"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu_alarm" {
  alarm_name          = "project3-ec2-high-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Triggers when EC2 CPU utilization reaches or exceeds 70%"

  dimensions = {
    InstanceId = aws_instance.monitored_ec2.id
  }

  treat_missing_data = "notBreaching"
}

output "instance_id" {
  value = aws_instance.monitored_ec2.id
}

output "instance_public_ip" {
  value = aws_instance.monitored_ec2.public_ip
}

output "alarm_name" {
  value = aws_cloudwatch_metric_alarm.high_cpu_alarm.alarm_name
}
