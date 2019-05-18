variable "ssh_port" {
  description = "SSH"
  default     = 22
}

variable "http_port" {
  description = "HTTP"
  default     = 80
}

variable "https_port" {
  description = "HTTPS"
  default     = 443
}

variable "key_name" {
  description = "Public Key"
  default     = "Nginx_key"
}

variable "ssh_key" {
  description = "Private Key"
  default     = "myprivatekey.pem"
}

variable "elastic_ip" {
  description = "Elastic IP Address"
  default     = "54.144.103.104"
}

#variable "vpc_endpoint_id" {
#  description = "VPN endpoint"
#}

#variable "db_remote_state_bucket" {
#  description = "The name of the S3 bucket used for the database's remote state storage"
#}

#variable "db_remote_state_key" {
#  description = "The name of the key in the S3 bucket used for the database's remote state storage"
#}
