// Existing Terraform src code found at /var/folders/b2/4ghn4z254ql56r7gv86brrdh0000gn/T/terraform_src.

data "aws_region" "current" {}

locals {
  mappings = {
    AWSRegionToAMI = {
      us-east-1 = {
        AMIID = "ami-09bee01cc997a78a6"
      }
      us-east-2 = {
        AMIID = "ami-0a9e12068cb98a01d"
      }
      us-west-1 = {
        AMIID = "ami-0fa6c8d131a220017"
      }
      us-west-2 = {
        AMIID = "ami-078c97cf1cefd1b38"
      }
      eu-west-1 = {
        AMIID = "ami-0c9ef930279337028"
      }
      eu-central-1 = {
        AMIID = "ami-065c1e34da68f2b02"
      }
      ap-northeast-1 = {
        AMIID = "ami-02265963d1614d04d"
      }
      ap-southeast-1 = {
        AMIID = "ami-0b68661b29b9e058c"
      }
      ap-southeast-2 = {
        AMIID = "ami-00e4b147599c13588"
      }
    }
  }
  stack_name = "ECS_EC2"
}

variable key_name {
  description = "Name of an existing EC2 KeyPair to enable SSH access to the ECS instances."
  type = string
}

variable vpc_id {
  description = "Select a VPC that allows instances to access the Internet."
  type = string
}

variable subnet_id {
  description = "Select at least two subnets in your selected VPC."
  type = string
}

variable desired_capacity {
  description = "Number of instances to launch in your ECS cluster."
  type = string
  default = "1"
}

variable max_size {
  description = "Maximum number of instances that can be launched in your ECS cluster."
  type = string
  default = "1"
}

variable instance_type {
  description = "EC2 instance type"
  type = string
  default = "t2.micro"
}

resource "aws_ecs_cluster" "ecs_cluster" {}

resource "aws_security_group" "ecs_security_group" {
  description = "ECS Security Group"
  vpc_id = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "ecs_security_group_htt_pinbound" {
  referenced_security_group_id = aws_security_group.ecs_security_group.arn
  ip_protocol = "tcp"
  from_port = 80
  to_port = 80
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_security_group_ss_hinbound" {
  referenced_security_group_id = aws_security_group.ecs_security_group.arn
  ip_protocol = "tcp"
  from_port = 22
  to_port = 22
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_security_group_al_bports" {
  referenced_security_group_id = aws_security_group.ecs_security_group.arn
  ip_protocol = "tcp"
  from_port = 31000
  to_port = 61000
  security_group_id = aws_security_group.ecs_security_group.arn
}

resource "aws_lb_target_group" "cloudwatch_logs_group" {
  name = join("-", ["ECSLogGroup", local.stack_name])
  // CF Property(RetentionInDays) = 14
}

resource "aws_ecs_task_definition" "taskdefinition" {
  family = join("", [local.stack_name, "-ecs-demo-app"])
  container_definitions = [
    {
      Name = "simple-app"
      Cpu = "10"
      Essential = "true"
      Image = "httpd:2.4"
      Memory = "300"
      LogConfiguration = {
        LogDriver = "awslogs"
        Options = {
          awslogs-group = aws_lb_target_group.cloudwatch_logs_group.arn_suffix
          awslogs-region = data.aws_region.current.name
          awslogs-stream-prefix = "ecs-demo-app"
        }
      }
      MountPoints = [
        {
          ContainerPath = "/usr/local/apache2/htdocs"
          SourceVolume = "my-vol"
        }
      ]
      PortMappings = [
        {
          ContainerPort = 80
        }
      ]
    },
    {
      Name = "busybox"
      Cpu = 10
      Command = [
        "/bin/sh -c "while true; do echo '<html> <head> <title>Amazon ECS Sample App</title> <style>body {margin-top: 40px; background-color: #333;} </style> </head><body> <div style=color:white;text-align:center> <h1>Amazon ECS Sample App</h1> <h2>Congratulations!</h2> <p>Your application is now running on a container in Amazon ECS.</p>' > top; /bin/date > date ; echo '</div></body></html>' > bottom; cat top date bottom > /usr/local/apache2/htdocs/index.html ; sleep 1; done""
      ]
      EntryPoint = [
        "sh",
        "-c"
      ]
      Essential = false
      Image = "busybox"
      Memory = 200
      LogConfiguration = {
        LogDriver = "awslogs"
        Options = {
          awslogs-group = aws_lb_target_group.cloudwatch_logs_group.arn_suffix
          awslogs-region = data.aws_region.current.name
          awslogs-stream-prefix = "ecs-demo-app"
        }
      }
      VolumesFrom = [
        {
          SourceContainer = "simple-app"
        }
      ]
    }
  ]
  volume = [
    {
      name = "my-vol"
    }
  ]
}

resource "aws_load_balancer_listener_policy" "ecsalb" {
  load_balancer_name = "ECSALB"
  // CF Property(Scheme) = "internet-facing"
  // CF Property(LoadBalancerAttributes) = [
  //   {
  //     Key = "idle_timeout.timeout_seconds"
  //     Value = "30"
  //   }
  // ]
  // CF Property(Subnets) = var.subnet_id
  // CF Property(SecurityGroups) = [
  //   aws_security_group.ecs_security_group.arn
  // ]
}

resource "aws_load_balancer_listener_policy" "alb_listener" {
  // CF Property(DefaultActions) = [
  //   {
  //     Type = "forward"
  //     TargetGroupArn = aws_lb_target_group_attachment.ecstg.id
  //   }
  // ]
  load_balancer_name = aws_load_balancer_listener_policy.ecsalb.id
  load_balancer_port = "80"
  // CF Property(Protocol) = "HTTP"
}

resource "aws_load_balancer_listener_policy" "ecsalb_listener_rule" {
  // CF Property(Actions) = [
  //   {
  //     Type = "forward"
  //     TargetGroupArn = aws_lb_target_group_attachment.ecstg.id
  //   }
  // ]
  // CF Property(Conditions) = [
  //   {
  //     Field = "path-pattern"
  //     Values = [
  //       "/"
  //     ]
  //   }
  // ]
  // CF Property(ListenerArn) = aws_load_balancer_listener_policy.alb_listener.id
  // CF Property(Priority) = 1
}

resource "aws_lb_target_group_attachment" "ecstg" {
  // CF Property(HealthCheckIntervalSeconds) = 10
  // CF Property(HealthCheckPath) = "/"
  // CF Property(HealthCheckProtocol) = "HTTP"
  // CF Property(HealthCheckTimeoutSeconds) = 5
  // CF Property(HealthyThresholdCount) = 2
  // CF Property(Name) = "ECSTG"
  port = 80
  // CF Property(Protocol) = "HTTP"
  // CF Property(UnhealthyThresholdCount) = 2
  target_id = var.vpc_id
}

resource "aws_autoscalingplans_scaling_plan" "ecs_auto_scaling_group" {
  // CF Property(VPCZoneIdentifier) = var.subnet_id
  name = aws_launch_configuration.container_instances.id
  min_capacity = "1"
  max_capacity = var.max_size
  predictive_scaling_max_capacity_behavior = var.desired_capacity
}

resource "aws_launch_configuration" "container_instances" {
  image_id = local.mappings["AWSRegionToAMI"][data.aws_region.current.name]["AMIID"]
  security_groups = [
    aws_security_group.ecs_security_group.arn
  ]
  instance_type = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.arn
  key_name = var.key_name
  user_data = base64encode(join("", ["#!/bin/bash -xe
", "echo ECS_CLUSTER=", aws_ecs_cluster.ecs_cluster.arn, " >> /etc/ecs/ecs.config
", "yum install -y aws-cfn-bootstrap
", "/opt/aws/bin/cfn-signal -e $? ", "         --stack ", local.stack_name, "         --resource ECSAutoScalingGroup ", "         --region ", data.aws_region.current.name, "
"]))
}

resource "aws_ecs_service" "service" {
  cluster = aws_ecs_cluster.ecs_cluster.arn
  desired_count = "1"
  load_balancer = [
    {
      container_name = "simple-app"
      container_port = "80"
      target_group_arn = aws_lb_target_group_attachment.ecstg.id
    }
  ]
  iam_role = aws_iam_role.ecs_service_role.arn
  task_definition = aws_ecs_task_definition.taskdefinition.arn
}

resource "aws_iam_role" "ecs_service_role" {
  assume_role_policy = {
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "ecs.amazonaws.com"
          ]
        }
        Action = [
          "sts:AssumeRole"
        ]
      }
    ]
  }
  path = "/"
  force_detach_policies = [
    {
      PolicyName = "ecs-service"
      PolicyDocument = {
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
              "elasticloadbalancing:DeregisterTargets",
              "elasticloadbalancing:Describe*",
              "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
              "elasticloadbalancing:RegisterTargets",
              "ec2:Describe*",
              "ec2:AuthorizeSecurityGroupIngress"
            ]
            Resource = "*"
          }
        ]
      }
    }
  ]
}

resource "aws_appautoscaling_target" "service_scaling_target" {
  max_capacity = 2
  min_capacity = 1
  resource_id = join("", ["service/", aws_ecs_cluster.ecs_cluster.arn, "/", aws_ecs_service.service.name])
  role_arn = aws_iam_role.autoscaling_role.arn
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace = "ecs"
}

resource "aws_applicationinsights_application" "service_scaling_policy" {
  resource_group_name = "AStepPolicy"
  // CF Property(PolicyType) = "StepScaling"
  // CF Property(ScalingTargetId) = aws_appautoscaling_target.service_scaling_target.arn
  // CF Property(StepScalingPolicyConfiguration) = {
  //   AdjustmentType = "PercentChangeInCapacity"
  //   Cooldown = 60
  //   MetricAggregationType = "Average"
  //   StepAdjustments = [
  //     {
  //       MetricIntervalLowerBound = 0
  //       ScalingAdjustment = 200
  //     }
  //   ]
  // }
}

resource "aws_cloudwatch_metric_alarm" "alb500s_alarm_scale_up" {
  evaluation_periods = "1"
  statistic = "Average"
  threshold = "10"
  alarm_description = "Alarm if our ALB generates too many HTTP 500s."
  period = "60"
  alarm_actions = [
    aws_applicationinsights_application.service_scaling_policy.arn
  ]
  namespace = "AWS/ApplicationELB"
  dimensions = [
    {
      Name = "LoadBalancer"
      Value = aws_load_balancer_listener_policy.ecsalb.load_balancer_name
    }
  ]
  comparison_operator = "GreaterThanThreshold"
  metric_name = "HTTPCode_ELB_5XX_Count"
}

resource "aws_iam_role" "ec2_role" {
  assume_role_policy = {
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "ec2.amazonaws.com"
          ]
        }
        Action = [
          "sts:AssumeRole"
        ]
      }
    ]
  }
  path = "/"
  force_detach_policies = [
    {
      PolicyName = "ecs-service"
      PolicyDocument = {
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "ecs:CreateCluster",
              "ecs:DeregisterContainerInstance",
              "ecs:DiscoverPollEndpoint",
              "ecs:Poll",
              "ecs:RegisterContainerInstance",
              "ecs:StartTelemetrySession",
              "ecs:Submit*",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
            ]
            Resource = "*"
          }
        ]
      }
    }
  ]
}

resource "aws_iam_role" "autoscaling_role" {
  assume_role_policy = {
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "application-autoscaling.amazonaws.com"
          ]
        }
        Action = [
          "sts:AssumeRole"
        ]
      }
    ]
  }
  path = "/"
  force_detach_policies = [
    {
      PolicyName = "service-autoscaling"
      PolicyDocument = {
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "application-autoscaling:*",
              "cloudwatch:DescribeAlarms",
              "cloudwatch:PutMetricAlarm",
              "ecs:DescribeServices",
              "ecs:UpdateService"
            ]
            Resource = "*"
          }
        ]
      }
    }
  ]
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  path = "/"
  role = [
    aws_iam_role.ec2_role.arn
  ]
}

output "ecsservice" {
  value = aws_ecs_service.service.cluster
}

output "ecscluster" {
  value = aws_ecs_cluster.ecs_cluster.arn
}

output "ecsalb" {
  description = "Your ALB DNS URL"
  value = join("", [aws_load_balancer_listener_policy.ecsalb.load_balancer_name])
}

output "taskdef" {
  value = aws_ecs_task_definition.taskdefinition.arn
}
