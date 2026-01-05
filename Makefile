.PHONY: help dev build post clean theme infra-init infra-plan infra-apply

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Hugo commands
dev: ## Start Hugo dev server
	hugo server -D

build: ## Build static site
	hugo --minify

post: ## Create new post (usage: make post)
	@if [ -z "$(TITLE)" ]; then echo "Usage: make post"; exit 1; fi
	@DIR="content/posts/$$(date +%Y-%m-%d)"; \
	mkdir -p "$$DIR"; \
	hugo new "posts/$$(date +%Y-%m-%d)/index.md"; \
	echo "Created: $$DIR/index.md"

# Theme
theme: ## Install hugo-blog-awesome theme
	git submodule add --depth=1 https://github.com/hugo-sid/hugo-blog-awesome.git themes/hugo-blog-awesome

theme-update: ## Update theme
	git submodule update --remote --merge

# Infrastructure
infra-init: ## Initialize Terraform
	cd terraform && terraform init

infra-plan: ## Plan Terraform changes
	cd terraform && terraform plan

infra-apply: ## Apply Terraform changes
	cd terraform && terraform apply

# Cleanup
clean: ## Remove generated files
	rm -rf public resources
