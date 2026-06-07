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

variable "notification_email" {
  type        = string
  description = "E-mail address that receives CloudWatch alarm notifications"
}

variable "cpu_high_threshold" {
  type        = number
  description = "CPU utilization threshold, in percent, for the CloudWatch alarm"

  validation {
    condition     = var.cpu_high_threshold > 0 && var.cpu_high_threshold <= 100
    error_message = "cpu_high_threshold must be between 1 and 100."
  }
}
