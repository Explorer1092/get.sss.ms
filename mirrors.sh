#!/bin/bash

# System Environment Optimization Script
# Configures package managers and Docker to use Alibaba Cloud acceleration mirrors

set -e

# Parse targets from environment variable or command line arguments
TARGETS="${TARGETS:-}"
if [ -z "$TARGETS" ]; then
    for arg in "$@"; do
        TARGETS="$TARGETS $arg"
    done
fi

# Check if specific target requested
should_configure() {
    local target=$1
    [ -z "$TARGETS" ] || echo "$TARGETS" | grep -qw "$target"
}

# Detect if running inside Docker container
is_docker_build() {
    [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null
}

# Configure Docker daemon with Alibaba Cloud mirror
configure_docker() {
    should_configure docker || return 0
    command -v docker &> /dev/null || return 0
    
    echo "Configuring Docker..."
    
    # Docker daemon config file
    DOCKER_CONFIG="/etc/docker/daemon.json"
    [ "$(uname)" == "Darwin" ] && DOCKER_CONFIG="$HOME/.docker/daemon.json"
    
    mkdir -p "$(dirname "$DOCKER_CONFIG")"
    
    # Check if we need sudo
    SUDO=""
    [ "$EUID" -ne 0 ] && [ "$(uname)" != "Darwin" ] && SUDO="sudo"
    
    # Backup existing config
    [ -f "$DOCKER_CONFIG" ] && $SUDO cp "$DOCKER_CONFIG" "${DOCKER_CONFIG}.bak"
    
    # Create or update Docker daemon config
    echo '{
  "registry-mirrors": ["https://docker.aliyun-inc.co"]
}' | $SUDO tee "$DOCKER_CONFIG" > /dev/null
    
    # Restart Docker daemon if not in container
    if ! is_docker_build && [ "$(uname)" == "Linux" ]; then
        systemctl is-active docker &>/dev/null && $SUDO systemctl restart docker
    fi
}

# Configure APT sources for Docker builds
configure_apt() {
    should_configure apt || return 0
    is_docker_build || return 0
    [ -f /etc/apt/sources.list ] || return 0
    
    echo "Configuring APT sources..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        cp /etc/apt/sources.list /etc/apt/sources.list.bak
        
        case "$ID" in
            ubuntu)
                sed -i 's|http://archive.ubuntu.com|http://mirrors.aliyun.com|g' /etc/apt/sources.list
                sed -i 's|http://security.ubuntu.com|http://mirrors.aliyun.com|g' /etc/apt/sources.list
                ;;
            debian)
                sed -i 's|http://deb.debian.org|http://mirrors.aliyun.com|g' /etc/apt/sources.list
                sed -i 's|http://security.debian.org|http://mirrors.aliyun.com|g' /etc/apt/sources.list
                ;;
        esac
        
        apt-get update 2>/dev/null || true
    fi
}

# Configure YUM/DNF sources for Docker builds
configure_yum() {
    should_configure yum || return 0
    is_docker_build || return 0
    [ -f /etc/yum.repos.d/CentOS-Base.repo ] || [ -f /etc/yum.repos.d/CentOS-Linux-BaseOS.repo ] || return 0
    
    echo "Configuring YUM/DNF sources..."
    
    mkdir -p /etc/yum.repos.d/backup
    mv /etc/yum.repos.d/CentOS-*.repo /etc/yum.repos.d/backup/ 2>/dev/null || true
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        VERSION_ID="${VERSION_ID%%.*}"
        curl -so /etc/yum.repos.d/CentOS-Base.repo \
            "http://mirrors.aliyun.com/repo/Centos-${VERSION_ID}.repo" 2>/dev/null || \
        curl -so /etc/yum.repos.d/CentOS-Base.repo \
            "http://mirrors.aliyun.com/repo/Centos-vault-${VERSION_ID}.repo" 2>/dev/null || true
    fi
}

# Configure package managers
configure_npm() {
    should_configure npm || return 0
    command -v npm &> /dev/null || return 0
    echo "Configuring npm..."
    npm config set registry https://registry.npmmirror.com/ 2>/dev/null
}

configure_yarn() {
    should_configure yarn || return 0
    command -v yarn &> /dev/null || return 0
    echo "Configuring yarn..."
    if yarn --version 2>/dev/null | grep -q "^1\."; then
        yarn config set registry https://registry.npmmirror.com/ 2>/dev/null || true
    else
        yarn config set npmRegistryServer https://registry.npmmirror.com/ 2>/dev/null || true
    fi
}

configure_pnpm() {
    should_configure pnpm || return 0
    command -v pnpm &> /dev/null || return 0
    echo "Configuring pnpm..."
    pnpm config set registry https://registry.npmmirror.com/ 2>/dev/null
}

configure_pip() {
    should_configure pip || return 0
    (command -v pip &> /dev/null || command -v pip3 &> /dev/null) || return 0
    echo "Configuring pip..."
    mkdir -p ~/.pip
    cat > ~/.pip/pip.conf << EOF
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/
trusted-host = mirrors.aliyun.com
EOF
    command -v pip3 &> /dev/null && pip3 config set global.index-url https://mirrors.aliyun.com/pypi/simple/ 2>/dev/null || true
}

configure_go() {
    should_configure go || return 0
    command -v go &> /dev/null || return 0
    echo "Configuring go..."
    go env -w GOPROXY=https://mirrors.aliyun.com/goproxy/,direct
    go env -w GOSUMDB=sum.golang.google.cn
}

configure_maven() {
    should_configure maven || return 0
    command -v mvn &> /dev/null || return 0
    echo "Configuring maven..."
    mkdir -p "$HOME/.m2"
    cat > "$HOME/.m2/settings.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0">
    <mirrors>
        <mirror>
            <id>aliyunmaven</id>
            <mirrorOf>*</mirrorOf>
            <name>Alibaba Cloud Maven Mirror</name>
            <url>https://maven.aliyun.com/repository/public</url>
        </mirror>
    </mirrors>
</settings>
EOF
}

configure_gradle() {
    should_configure gradle || return 0
    command -v gradle &> /dev/null || return 0
    echo "Configuring gradle..."
    mkdir -p "$HOME/.gradle"
    cat > "$HOME/.gradle/init.gradle" << 'EOF'
allprojects {
    repositories {
        maven { url 'https://maven.aliyun.com/repository/public' }
        maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
        mavenCentral()
    }
}
EOF
}

configure_composer() {
    should_configure composer || return 0
    command -v composer &> /dev/null || return 0
    echo "Configuring composer..."
    composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/ 2>/dev/null || true
}

configure_gem() {
    should_configure gem || should_configure rubygems || return 0
    command -v gem &> /dev/null || return 0
    echo "Configuring rubygems..."
    gem sources --add https://mirrors.aliyun.com/rubygems/ --remove https://rubygems.org/ 2>/dev/null || true
}

configure_cargo() {
    should_configure cargo || should_configure rust || return 0
    command -v cargo &> /dev/null || return 0
    echo "Configuring cargo..."
    mkdir -p ~/.cargo
    cat > ~/.cargo/config.toml << 'EOF'
[source.crates-io]
replace-with = 'ustc'
[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
EOF
}

# Show usage
show_usage() {
    echo "Usage: curl -sL https://get.sss.ms/mirrors.sh | bash [options]"
    echo "   or: $0 [options]"
    echo ""
    echo "Options:"
    echo "  docker     - Configure Docker registry mirror"
    echo "  apt        - Configure APT sources (Docker builds only)"
    echo "  yum        - Configure YUM/DNF sources (Docker builds only)"
    echo "  npm        - Configure npm registry"
    echo "  yarn       - Configure yarn registry"
    echo "  pnpm       - Configure pnpm registry"
    echo "  pip        - Configure pip index"
    echo "  go         - Configure Go proxy"
    echo "  maven      - Configure Maven repository"
    echo "  gradle     - Configure Gradle repository"
    echo "  composer   - Configure Composer repository"
    echo "  gem        - Configure RubyGems source"
    echo "  rubygems   - Same as gem"
    echo "  cargo      - Configure Cargo registry"
    echo "  rust       - Same as cargo"
    echo "  help       - Show this help message"
    echo ""
    echo "Examples:"
    echo "  curl -sL https://get.sss.ms/mirrors.sh | bash"
    echo "  curl -sL https://get.sss.ms/mirrors.sh | TARGETS=\"npm pip\" bash"
    echo "  curl -sL https://get.sss.ms/mirrors.sh | TARGETS=\"docker\" bash"
}

# Main execution
main() {
    # Check for help
    if echo "$TARGETS" | grep -qw "help"; then
        show_usage
        exit 0
    fi
    
    echo "System Environment Optimization"
    [ -n "$TARGETS" ] && echo "Targets:$TARGETS"
    echo ""
    
    # Configure Docker and system package sources
    if is_docker_build; then
        configure_apt
        configure_yum
    else
        configure_docker
    fi
    
    # Configure package managers
    configure_npm
    configure_yarn
    configure_pnpm
    configure_pip
    configure_go
    configure_maven
    configure_gradle
    configure_composer
    configure_gem
    configure_cargo
    
    echo ""
    echo "Configuration complete"
}

main "$@"