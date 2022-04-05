variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-west-2"
}

variable "handler_name" {
  type        = string
  description = "The name of the function handler exported by your lambda library code."
}

variable "lambda_name" {
  type        = string
  description = "The name of this lambda function."
}

variable "environment" {
  type        = string
  description = "The name of the environment (e.g. prod, dev, qa)."
}

variable "cron-minutes" {
  type        = string
  description = "The minute the cron should execute."
}

variable "cron-hours" {
  type        = string
  description = "The hours the cron should execute."
}

