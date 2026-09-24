variable "name" {
  default     = null
  description = "Name used for both the task definition family and the service."
}

variable "cluster_arn" {
  default     = null
  description = "ARN (or name) of the ECS cluster to run the service in."
}

variable "launch_type" {
  default     = "FARGATE"
  description = "Launch type for the service (e.g. 'FARGATE', 'EC2', or 'EXTERNAL')."
}

variable "network_mode" {
  default     = "awsvpc"
  description = "Docker networking mode for the task definition (e.g. 'awsvpc', 'bridge', 'host', or 'none'). Fargate requires 'awsvpc'; network_configuration is only set on the service when this is 'awsvpc'."
}

variable "requires_compatibilities" {
  default     = ["FARGATE"]
  description = "Launch types the task definition is compatible with."
}

variable "cpu" {
  default     = 256
  description = "CPU units for the task."
}

variable "memory" {
  default     = 512
  description = "Memory (MiB) for the task."
}

variable "execution_role_arn" {
  default     = null
  description = "The ARN of the IAM role ECS assumes to pull the image and write logs."
}

variable "task_role_arn" {
  default     = null
  description = "The ARN of the IAM role the task's containers assume."
}

variable "container_definitions" {
  default     = null
  description = "JSON-encoded container definitions, exactly as accepted by aws_ecs_task_definition (e.g. the result of jsonencode([...]))."
}

variable "desired_count" {
  default     = 1
  description = "Number of task instances to run."
}

variable "subnet_ids" {
  default     = []
  description = "IDs of the subnets the service's tasks run in."
}

variable "security_group_ids" {
  default     = null
  description = "IDs of the security groups to associate with the service's tasks."
}

variable "assign_public_ip" {
  default     = false
  description = "Whether to assign a public IP address to each task's elastic network interface."
}

variable "volumes" {
  default     = []
  description = "EFS-backed volumes to make available to the task's containers."
  type = list(object({
    name               = string
    file_system_id     = string
    access_point_id    = optional(string)
    transit_encryption = optional(string, "ENABLED")
    iam                = optional(string, "DISABLED")
  }))
}

variable "load_balancer" {
  default     = null
  description = "Load balancer target group this service registers its tasks with."
  type = object({
    container_name   = string
    container_port   = number
    target_group_arn = string
  })
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to the service and task definition."
}
