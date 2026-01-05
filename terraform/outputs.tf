output "pages_project_name" {
  description = "Cloudflare Pages project name"
  value       = cloudflare_pages_project.blog.name
}

output "pages_subdomain" {
  description = "Cloudflare Pages subdomain"
  value       = cloudflare_pages_project.blog.subdomain
}

output "custom_domain" {
  description = "Custom domain for the blog"
  value       = cloudflare_pages_domain.blog.domain
}
