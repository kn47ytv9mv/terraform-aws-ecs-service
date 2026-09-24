# terraform-aws-ecs-service

Terraform module for an ECS task definition and its service, bundled
together since they are essentially always 1:1. Defaults to Fargate
(`launch_type = "FARGATE"`, `network_mode = "awsvpc"`), but neither is
hardcoded — `EC2`/`EXTERNAL` launch types work too, with `network_mode`
set to `"bridge"`, `"host"`, or `"none"` (the service's
`network_configuration` block is only set when `network_mode` is
`"awsvpc"`).

## Cost

On Fargate, this module bills per vCPU and per gigabyte of memory
consumed for as long as tasks are running; setting `desired_count = 0`
stops the charge entirely. On the EC2 launch type, cost comes from the
underlying EC2 instances, not this module. See
AWS's [Fargate pricing](https://aws.amazon.com/fargate/pricing/) page
for current rates.

## Usage

```hcl
module "service" {
  source = "kn47ytv9mv/ecs-service/aws"

  name        = "example"
  cluster_arn = module.cluster.arn

  execution_role_arn = module.execution_role.arn
  task_role_arn      = module.task_role.arn

  container_definitions = jsonencode([
    {
      name  = "example"
      image = "example:latest"

      portMappings = [
        { containerPort = 8080, hostPort = 8080, protocol = "tcp" }
      ]
    }
  ])

  subnet_ids         = module.private_subnets[*].id
  security_group_ids = [module.service_security_group.id]
}
```

Or directly from this repository:

```hcl
module "service" {
  source = "github.com/kn47ytv9mv/terraform-aws-ecs-service"

  name        = "example"
  cluster_arn = module.cluster.arn

  execution_role_arn = module.execution_role.arn
  task_role_arn      = module.task_role.arn

  container_definitions = jsonencode([
    {
      name  = "example"
      image = "example:latest"

      portMappings = [
        { containerPort = 8080, hostPort = 8080, protocol = "tcp" }
      ]
    }
  ])

  subnet_ids         = module.private_subnets[*].id
  security_group_ids = [module.service_security_group.id]
}
```

With an EFS-backed volume and an ALB target group:

```hcl
module "service" {
  source = "kn47ytv9mv/ecs-service/aws"

  name        = "example"
  cluster_arn = module.cluster.arn

  execution_role_arn = module.execution_role.arn
  task_role_arn      = module.task_role.arn

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
      file_system_id  = module.efs.id
      access_point_id = module.efs_access_point.id
    }
  ]

  load_balancer = {
    target_group_arn = module.target_group.arn
    container_name   = "example"
    container_port   = 8080
  }

  subnet_ids         = module.private_subnets[*].id
  security_group_ids = [module.service_security_group.id]

  depends_on = [module.efs, module.https_listener]
}
```

**Note:** add an explicit `depends_on` on this module block for two things
Terraform cannot infer from argument references alone:
- **An EFS volume** needs the module (or resource) that creates the
  *mount targets* — the volume configuration only references the file
  system itself, not its mount targets, e.g. `module.efs`.
- **A load balancer** needs the listener module for the target group
  this service registers with — ECS requires the target group to already
  have an associated listener, but `load_balancer.target_group_arn` only
  references the target group, not the listener, e.g. `module.https_listener`.

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.3 |
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| name | Name used for both the task definition family and the service. | `null` | no |
| cluster_arn | ARN (or name) of the ECS cluster to run the service in. | `null` | no |
| launch_type | Launch type for the service (e.g. `'FARGATE'`, `'EC2'`, or `'EXTERNAL'`). | `"FARGATE"` | no |
| network_mode | Docker networking mode for the task definition (e.g. `'awsvpc'`, `'bridge'`, `'host'`, or `'none'`). Fargate requires `'awsvpc'`; `network_configuration` is only set on the service when this is `'awsvpc'`. | `"awsvpc"` | no |
| requires_compatibilities | Launch types the task definition is compatible with. | `["FARGATE"]` | no |
| cpu | CPU units for the task. | `256` | no |
| memory | Memory (MiB) for the task. | `512` | no |
| execution_role_arn | The ARN of the IAM role ECS assumes to pull the image and write logs. | `null` | no |
| task_role_arn | The ARN of the IAM role the task's containers assume. | `null` | no |
| container_definitions | JSON-encoded container definitions, exactly as accepted by `aws_ecs_task_definition` (e.g. the result of `jsonencode([...])`). | `null` | no |
| desired_count | Number of task instances to run. | `1` | no |
| subnet_ids | IDs of the subnets the service's tasks run in. | `[]` | no |
| security_group_ids | IDs of the security groups to associate with the service's tasks. | `null` | no |
| assign_public_ip | Whether to assign a public IP address to each task's elastic network interface. | `false` | no |
| volumes | EFS-backed volumes to make available to the task's containers. | `[]` | no |
| load_balancer | Load balancer target group this service registers its tasks with. | `null` | no |
| tags | A map of tags to assign to the service and task definition. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| id | The ID of the service. |
| arn | The ARN of the service. |
| task_definition_arn | The ARN of the task definition. |
| name | The name of the service. Feed this into `terraform-aws-monitoring-baseline`'s `ecs_services` — CloudWatch dimensions service metrics on the service name, not its ARN. |

## License

MIT — see [LICENSE.md](LICENSE.md).
