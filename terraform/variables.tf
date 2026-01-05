variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID (optional, for DNS record creation)"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Cloudflare Pages project name"
  type        = string
  default     = "blog"
}

variable "custom_domain" {
  description = "Custom domain for the blog"
  type        = string
}

variable "dns_record_name" {
  description = "DNS record name (e.g., 'blog' for blog.example.com, '@' for apex)"
  type        = string
  default     = "@"
}
