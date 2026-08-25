locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # ALB/Target Group names have a hard 32-char AWS limit
  short_prefix = substr("${var.project_name}-${var.environment}", 0, 20)
}

resource "aws_lb" "main" {
  name               = "${local.short_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "${local.short_prefix}-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name = "${local.name_prefix}-app-tg"
  }
}

resource "aws_lb_target_group_attachment" "app" {
  count            = length(var.app_instance_ids)
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = var.app_instance_ids[count.index]
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}