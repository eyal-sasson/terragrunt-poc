variable "name" {
  type        = string
  description = "The name of the Redis instance"
}

variable "node_type" {
  type        = string
  description = "The node type of the Redis instance (small, medium, large)"

  validation {
    condition     = contains(["small", "medium", "large"], var.node_type)
    error_message = "node_type must be one of: small, medium, large."
  }
}

variable "version" {
  type        = string
  description = "The Redis version"
}

variable "output_dir" {
  type        = string
  description = "Absolute directory where the simulated resource file is written"
}
