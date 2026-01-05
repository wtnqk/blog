terraform {
  required_version = ">= 1.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Cloudflare Pages Project
resource "cloudflare_pages_project" "blog" {
  account_id        = var.cloudflare_account_id
  name              = var.project_name
  production_branch = "main"

  build_config {
    build_command   = ""
    destination_dir = ""
  }

  deployment_configs {
    production {
      compatibility_date = "2024-01-01"
    }
    preview {
      compatibility_date = "2024-01-01"
    }
  }
}

# Custom Domain
resource "cloudflare_pages_domain" "blog" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.blog.name
  domain       = var.custom_domain
}

# DNS Record for custom domain (if zone is managed by Cloudflare)
resource "cloudflare_record" "blog" {
  count           = var.cloudflare_zone_id != "" ? 1 : 0
  zone_id         = var.cloudflare_zone_id
  name            = var.dns_record_name
  content         = cloudflare_pages_project.blog.subdomain
  type            = "CNAME"
  proxied         = true
  allow_overwrite = true
}
