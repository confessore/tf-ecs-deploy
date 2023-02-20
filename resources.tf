resource "aws_alb" "alb" {
  name               = local.alb["name"]     # tf-alb
  internal           = local.alb["internal"] # false
  load_balancer_type = "application"

  subnets            = [for s in data.aws_subnet.subnets : s.id]
}

resource "aws_alb_target_group" "group" {
  name        = local.alb.target_group["name"]
  port        = local.alb.target_group["port"]
  protocol    = local.alb.target_group["protocol"]
  vpc_id      = data.aws_vpc.main.id
  target_type = "ip"

  depends_on = [aws_alb.alb]
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.group.arn
  }
}

resource "aws_ecs_cluster" "cluster" {
  name               = local.ecs["cluster_name"]  # "ecs-cluster"
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = "100"
  }
}

resource "aws_ecs_task_definition" "task" {
  family = "service"
  requires_compatibilities = [
    "FARGATE",
  ]
  execution_role_arn = aws_iam_role.fargate.arn
  network_mode       = "awsvpc"
  cpu                = 1024
  memory             = 3072
  container_definitions = jsonencode([
    {
      name      = local.container.name   # "application"
      image     = local.container.image  # "particule/helloworld"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "service" {
  name            = local.ecs.service_name
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 1

  network_configuration {
    subnets          = [for s in data.aws_subnet.subnets : s.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.group.arn  # our target group
    container_name   = local.container.name           # "application"
    container_port   = 80
  }
  capacity_provider_strategy {
    base              = 0
    capacity_provider = "FARGATE"
    weight            = 100
  }
}

resource "aws_ecr_repository" "repository" {
  name                 = local.ecr["repository_name"]  # "repository"
  image_tag_mutability = "MUTABLE"
}

resource "aws_iam_user" "publisher" {
  name = "ecr-publisher"
  path = "/serviceaccounts/"
}

resource "aws_iam_role" "fargate" {
  name = "fargate-role"
  path = "/serviceaccounts/"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = [
            "ecs.amazonaws.com",
            "ecs-tasks.amazonaws.com"
          ]
        }
      },
    ]
  })
}


resource "aws_iam_user_policy" "publisher" {
  name = "ecr-publisher"
  user = aws_iam_user.publisher.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "iam:PassRole",
        "iam:GetRole",
        "ecs:DescribeTaskDefinition",
        "ecs:DescribeServices",
        "ecs:UpdateService",
        "ecs:RegisterTaskDefinition",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:GetAuthorizationToken",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetLifecyclePolicy",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_access_key" "publisher" {
  user = aws_iam_user.publisher.name
}

resource "aws_iam_role_policy" "fargate" {
  name = "fargate-execution-role"
  role = aws_iam_role.fargate.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:GetAuthorizationToken",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetLifecyclePolicy"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}