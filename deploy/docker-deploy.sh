#!/usr/bin/env bash
set -euo pipefail

# Kiro-Go Docker deployment preparation script.
# It downloads deployment templates, generates a secure admin password,
# and creates the persistent data directory for Docker Compose.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

GITHUB_RAW_URL="${GITHUB_RAW_URL:-https://raw.githubusercontent.com/luka7620/Kiro-Go/main/deploy}"

print_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

download_file() {
  local url="$1"
  local output="$2"

  if command_exists curl; then
    curl -fsSL "$url" -o "$output"
  elif command_exists wget; then
    wget -q "$url" -O "$output"
  else
    print_error "Neither curl nor wget is installed. Please install one of them first."
    exit 1
  fi
}

generate_secret() {
  if command_exists openssl; then
    openssl rand -hex 16
  elif [ -r /dev/urandom ] && command_exists od; then
    od -An -N16 -tx1 /dev/urandom | tr -d ' \n'
  else
    date +%s%N | sha256sum | awk '{print substr($1,1,32)}'
  fi
}

replace_env_value() {
  local key="$1"
  local value="$2"
  local file="$3"

  if sed --version >/dev/null 2>&1; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    sed -i '' "s|^${key}=.*|${key}=${value}|" "$file"
  fi
}

confirm_overwrite() {
  if [ "${KIRO_GO_OVERWRITE:-}" = "1" ]; then
    return 0
  fi

  if [ ! -e docker-compose.yml ] && [ ! -e .env ]; then
    return 0
  fi

  print_warning "docker-compose.yml or .env already exists in the current directory."

  if [ -r /dev/tty ]; then
    read -r -p "Overwrite existing deployment files? (y/N): " reply </dev/tty
    if [[ "$reply" =~ ^[Yy]$ ]]; then
      return 0
    fi
  fi

  print_info "Cancelled."
  exit 0
}

main() {
  echo ""
  echo "=========================================="
  echo " Kiro-Go Docker Deployment Preparation"
  echo "=========================================="
  echo ""

  confirm_overwrite

  print_info "Downloading docker-compose.yml..."
  download_file "${GITHUB_RAW_URL}/docker-compose.local.yml" docker-compose.yml
  print_success "Downloaded docker-compose.yml"

  print_info "Downloading .env.example..."
  download_file "${GITHUB_RAW_URL}/.env.example" .env.example
  print_success "Downloaded .env.example"

  print_info "Generating .env..."
  cp .env.example .env

  admin_password="$(generate_secret)"
  replace_env_value "ADMIN_PASSWORD" "$admin_password" .env
  chmod 600 .env

  print_info "Creating data directory..."
  mkdir -p data
  print_success "Created data directory"

  if command_exists docker; then
    if docker compose version >/dev/null 2>&1; then
      print_info "Validating Docker Compose configuration..."
      docker compose config >/dev/null
      print_success "Docker Compose configuration is valid"
    else
      print_warning "Docker Compose plugin was not found. Install Docker Compose before starting the service."
    fi
  else
    print_warning "Docker was not found. Install Docker before starting the service."
  fi

  echo ""
  echo "=========================================="
  echo " Preparation Complete"
  echo "=========================================="
  echo ""
  echo "Generated admin password:"
  echo "  ${admin_password}"
  echo ""
  print_warning "The password has been saved to .env. Keep it private."
  echo ""
  echo "Next steps:"
  echo "  docker compose up -d"
  echo "  docker compose logs -f kiro-go"
  echo ""
  echo "Admin panel:"
  echo "  http://localhost:8080/admin"
  echo ""
}

main "$@"
