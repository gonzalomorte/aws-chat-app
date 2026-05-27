variable "db_username" {
  type        = string
  description = "RDS master username"
  default     = "chatuser"
}

variable "db_password" {
  type        = string
  description = "RDS master password"
  sensitive   = true
}
