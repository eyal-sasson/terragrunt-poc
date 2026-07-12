variable "db_name" {
  type        = string
  description = "The name of the database"
}

variable "size" {
  type        = string
  description = "The size of the database (small, medium, large)"

  validation {
    condition     = contains(["small", "medium", "large"], var.size)
    error_message = "size must be one of: small, medium, large."
  }
}

variable "pg_version" {
  type        = string
  description = "The Postgres version"
}

variable "output_dir" {
  type        = string
  description = "Absolute directory where the simulated resource file is written"
}
