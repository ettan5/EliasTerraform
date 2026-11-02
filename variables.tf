variable "min_replicas" {
  description = "Number of min  replicas for the application"
  type        = number
  default     = 1
}
variable "max_replicas" {
  description = "Number of max  replicas for the application"
  type        = number
  default     = 5
}