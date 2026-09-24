resource "random_uuid" "resource" {}

resource "aws_ecs_task_definition" "resource" {
  family                   = coalesce(var.name, random_uuid.resource.id)
  cpu                      = var.cpu
  memory                   = var.memory
  network_mode             = var.network_mode
  requires_compatibilities = var.requires_compatibilities

  execution_role_arn = var.execution_role_arn
  task_role_arn      = var.task_role_arn

  container_definitions = var.container_definitions

  dynamic "volume" {
    for_each = { for volume in var.volumes : volume.name => volume }

    content {
      name = volume.value.name

      efs_volume_configuration {
        file_system_id     = volume.value.file_system_id
        transit_encryption = volume.value.transit_encryption

        dynamic "authorization_config" {
          for_each = volume.value.access_point_id[*]

          content {
            access_point_id = authorization_config.value
            iam             = volume.value.iam
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_ecs_service" "resource" {
  name          = coalesce(var.name, random_uuid.resource.id)
  cluster       = var.cluster_arn
  launch_type   = var.launch_type
  desired_count = var.desired_count

  task_definition = aws_ecs_task_definition.resource.arn

  dynamic "network_configuration" {
    for_each = var.network_mode == "awsvpc" ? [1] : []

    content {
      subnets          = var.subnet_ids
      security_groups  = var.security_group_ids
      assign_public_ip = var.assign_public_ip
    }
  }

  dynamic "load_balancer" {
    for_each = var.load_balancer[*]

    content {
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
      target_group_arn = load_balancer.value.target_group_arn
    }
  }

  tags = var.tags
}

output "id" {
  description = "The ID of the service."
  value       = aws_ecs_service.resource.id
}

output "name" {
  description = "The name of the service. Feed this into terraform-aws-monitoring-baseline's ecs_services — CloudWatch dimensions the service metrics on the service name, not its ARN."
  value       = aws_ecs_service.resource.name
}

output "arn" {
  description = "The ARN of the service."
  value       = aws_ecs_service.resource.arn
}

output "task_definition_arn" {
  description = "The ARN of the task definition."
  value       = aws_ecs_task_definition.resource.arn
}
