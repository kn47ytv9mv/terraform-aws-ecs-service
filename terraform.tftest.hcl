mock_provider "aws" {}

run "default_uses_generated_name_and_fargate_defaults" {
  command = apply

  variables {
    container_definitions = jsonencode([{ name = "app", image = "nginx" }])
  }

  assert {
    condition     = aws_ecs_task_definition.resource.family == random_uuid.resource.id
    error_message = "With no name given, the task family should use the generated random_uuid."
  }

  assert {
    condition     = aws_ecs_service.resource.name == random_uuid.resource.id
    error_message = "With no name given, the service should use the generated random_uuid."
  }

  assert {
    condition     = aws_ecs_service.resource.launch_type == "FARGATE"
    error_message = "launch_type should default to FARGATE."
  }

  assert {
    condition     = aws_ecs_task_definition.resource.network_mode == "awsvpc"
    error_message = "network_mode should default to awsvpc."
  }

  assert {
    condition     = length(aws_ecs_service.resource.network_configuration) == 1
    error_message = "network_configuration should be set when network_mode is awsvpc (the default)."
  }
}

run "explicit_name_overrides_generated_uuid" {
  command = plan

  variables {
    container_definitions = jsonencode([{ name = "app", image = "nginx" }])

    name = "example"
  }

  assert {
    condition     = aws_ecs_task_definition.resource.family == "example"
    error_message = "An explicit name should be used for the task family instead of the generated UUID."
  }

  assert {
    condition     = aws_ecs_service.resource.name == "example"
    error_message = "An explicit name should be used for the service instead of the generated UUID."
  }
}

run "non_awsvpc_network_mode_omits_network_configuration" {
  command = plan

  variables {
    container_definitions = jsonencode([{ name = "app", image = "nginx" }])

    network_mode             = "bridge"
    requires_compatibilities = ["EC2"]
    launch_type              = "EC2"
  }

  assert {
    condition     = length(aws_ecs_service.resource.network_configuration) == 0
    error_message = "network_configuration should be omitted entirely when network_mode is not awsvpc."
  }
}

run "volume_without_access_point_omits_authorization_config" {
  command = plan

  variables {
    container_definitions = jsonencode([{ name = "app", image = "nginx" }])

    volumes = [{
      name           = "data"
      file_system_id = "fs-0123456789abcdef0"
    }]
  }

  assert {
    condition     = length(aws_ecs_task_definition.resource.volume) == 1
    error_message = "volumes should create one volume block per entry."
  }

  assert {
    condition     = one(aws_ecs_task_definition.resource.volume).efs_volume_configuration[0].transit_encryption == "ENABLED"
    error_message = "transit_encryption should default to ENABLED."
  }

  assert {
    condition     = length(one(aws_ecs_task_definition.resource.volume).efs_volume_configuration[0].authorization_config) == 0
    error_message = "authorization_config should be omitted when access_point_id is not set."
  }
}

run "volume_with_access_point_sets_authorization_config" {
  command = plan

  variables {
    container_definitions = jsonencode([{ name = "app", image = "nginx" }])

    volumes = [{
      name            = "data"
      file_system_id  = "fs-0123456789abcdef0"
      access_point_id = "fsap-0123456789abcdef0"
      iam             = "ENABLED"
    }]
  }

  assert {
    condition     = length(one(aws_ecs_task_definition.resource.volume).efs_volume_configuration[0].authorization_config) == 1
    error_message = "authorization_config should be set when access_point_id is given."
  }

  assert {
    condition     = one(one(aws_ecs_task_definition.resource.volume).efs_volume_configuration[0].authorization_config).access_point_id == "fsap-0123456789abcdef0"
    error_message = "authorization_config should carry the supplied access_point_id."
  }
}

run "load_balancer_unset_by_default" {
  command = plan

  variables {
    container_definitions = jsonencode([{ name = "app", image = "nginx" }])
  }

  assert {
    condition     = length(aws_ecs_service.resource.load_balancer) == 0
    error_message = "load_balancer should be omitted when not set."
  }
}

run "load_balancer_set_when_given" {
  command = plan

  variables {
    container_definitions = jsonencode([{ name = "app", image = "nginx" }])

    load_balancer = {
      container_name   = "example"
      container_port   = 8080
      target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/example/0123456789abcdef"
    }
  }

  assert {
    condition     = length(aws_ecs_service.resource.load_balancer) == 1
    error_message = "load_balancer should be set on the service when given."
  }

  assert {
    condition     = one(aws_ecs_service.resource.load_balancer).container_port == 8080
    error_message = "load_balancer's container_port should pass through."
  }
}

run "readme_basic_container_definitions" {
  command = plan

  variables {
    name        = "example"
    cluster_arn = "arn:aws:ecs:us-east-1:123456789012:cluster/example"

    execution_role_arn = "arn:aws:iam::123456789012:role/example-execution"
    task_role_arn      = "arn:aws:iam::123456789012:role/example-task"

    container_definitions = jsonencode([
      {
        name  = "example"
        image = "example:latest"

        portMappings = [
          { containerPort = 8080, hostPort = 8080, protocol = "tcp" }
        ]
      }
    ])

    subnet_ids         = ["subnet-0123456789abcdef0"]
    security_group_ids = ["sg-0123456789abcdef0"]
  }
}

run "readme_efs_volume_and_alb_target_group" {
  command = plan

  variables {
    name        = "example"
    cluster_arn = "arn:aws:ecs:us-east-1:123456789012:cluster/example"

    execution_role_arn = "arn:aws:iam::123456789012:role/example-execution"
    task_role_arn      = "arn:aws:iam::123456789012:role/example-task"

    container_definitions = jsonencode([
      {
        name  = "example"
        image = "example:latest"

        portMappings = [
          { containerPort = 8080, hostPort = 8080, protocol = "tcp" }
        ]

        mountPoints = [
          { sourceVolume = "data", containerPath = "/data", readOnly = false }
        ]
      }
    ])

    volumes = [
      {
        name            = "data"
        file_system_id  = "fs-0123456789abcdef0"
        access_point_id = "fsap-0123456789abcdef0"
      }
    ]

    load_balancer = {
      target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/example/0123456789abcdef"
      container_name   = "example"
      container_port   = 8080
    }

    subnet_ids         = ["subnet-0123456789abcdef0"]
    security_group_ids = ["sg-0123456789abcdef0"]
  }
}
