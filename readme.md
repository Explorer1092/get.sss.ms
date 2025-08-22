## 镜像加速配置脚本

一键配置系统各种包管理器使用阿里云/国内镜像加速，支持 Docker、npm、pip、go 等常用工具。

### 默认配置所有检测到的工具
```bash
curl -sL https://get.sss.ms/mirrors.sh | bash
```

### 仅配置特定工具（通过环境变量）
```bash
# 仅配置 npm
curl -sL https://get.sss.ms/mirrors.sh | TARGETS="npm" bash

# 配置 npm 和 pip
curl -sL https://get.sss.ms/mirrors.sh | TARGETS="npm pip" bash

# 仅配置 Docker
curl -sL https://get.sss.ms/mirrors.sh | TARGETS="docker" bash
```

### 支持的优化目标
- `docker` - Docker 镜像加速
- `apt` - APT 源（Docker 构建环境）
- `yum` - YUM/DNF 源（Docker 构建环境）
- `npm` - npm 注册表
- `yarn` - Yarn 注册表
- `pnpm` - pnpm 注册表
- `pip` - pip 索引
- `go` - Go 代理
- `maven` - Maven 仓库
- `gradle` - Gradle 仓库
- `composer` - Composer 仓库
- `gem`/`rubygems` - RubyGems 源
- `cargo`/`rust` - Cargo 注册表

---

## Docker 相关

### 安装 Docker（使用阿里云安装源）

```
curl -fsSL https://get.sss.ms/docker.sh -o get-docker.sh
sh get-docker.sh --mirror Aliyun
```

### Linux 一条命令：设置 Docker 加速/翻墙地址为 docker.aliyun-inc.co（无外部脚本）

```
sudo mkdir -p /etc/docker && echo '{"registry-mirrors":["https://docker.aliyun-inc.co"]}' | sudo tee /etc/docker/daemon.json >/dev/null && sudo systemctl daemon-reload && sudo systemctl restart docker
```

### 备选（仅需传入地址）：使用 DaoCloud 一条命令

```
curl -sSL https://get.sss.ms/set_mirror.sh | sudo sh -s https://docker.aliyun-inc.co && sudo systemctl daemon-reload && sudo systemctl restart docker
```

提示：上述第一条命令会覆盖现有的 `/etc/docker/daemon.json`。如需保留其他配置，可先备份或使用 `jq` 合并配置后再重启 Docker。
