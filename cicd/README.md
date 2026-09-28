# RuoYi-Cloud CI/CD 与容器化部署配置（cicd/）

本目录与 `.github/workflows/` 下的工作流共同构成一套**全部手动触发**的 GitHub Actions 流水线，用于将 RuoYi-Cloud 后端打包、发布到 GitHub Packages / Release、构建多架构容器镜像并部署验证。

## 设计原则（已锁定）

- **全部手动触发**：所有工作流均为 `workflow_dispatch`，在 Actions 页手动运行并填写版本号。
- **版本号手动填写**：输入纯语义版本（如 `3.6.8`，不含 `v` 前缀）；Release tag 为 `v3.6.8`；镜像 tag 为 `3.6.8` + `latest`。
- **零镜像 / 零加速**：Maven 直连 Maven Central（通过 `mirrorOf=*` 强制，杜绝任何镜像，含中国地区加速）；npm 直连 registry.npmjs.org；容器基础镜像使用 docker.io 官方原版。
- **最新基础软件**：JDK 17（项目硬要求，不可升级）+ Eclipse Temurin 最新；Maven 3.9.16；Node 22 LTS；基础镜像 `eclipse-temurin:17-jre` / `nginx:1.27-alpine` / `mysql:8.0` / `redis:7-alpine` / `nacos/nacos-server:v3.0.2`。
- **多架构**：后端 JAR 与前端 dist 本身跨平台；容器镜像通过 buildx + QEMU 构建 `linux/amd64,linux/arm64` 多架构 manifest。
- **不动上游代码结构**：新增配置集中在 `.github/workflows/` 与 `cicd/`，未修改 `docker/`、`ruoyi-*`、`sql/` 等上游目录，便于后续 `git pull` 上游更新。

## 工作流（在 Actions 页手动触发）

| 工作流 | 仓库 | 作用 |
| --- | --- | --- |
| `release-backend.yml` | RuoYi-Cloud | Maven 打包 → 发布到 GitHub Maven Packages(`com.ruoyi`) + 创建 Release 上传 7 个 fat-jar |
| `release-frontend.yml` | RuoYi-Vue3 | `npm run build:prod` → 创建 Release 上传 `ruoyi-web-dist.zip` |
| `build-images-backend.yml` | RuoYi-Cloud | 下载 Release JAR → 构建 7 个后端多架构镜像 → `ghcr.io/zhuyifeiRuichuang/ruoyi-cloud/ruoyi-<svc>` |
| `build-images-frontend.yml` | RuoYi-Vue3 | 下载 dist → 构建前端多架构镜像 → `ghcr.io/zhuyifeiRuichuang/ruoyi-vue3/ruoyi-web` |
| `deploy-test.yml` | RuoYi-Cloud | **在线**验证：Docker Compose 全栈 + 标准 K8s(kind) 双路，仅 amd64 |

## 推荐执行顺序

1. 在 **RuoYi-Cloud** 手动运行 `release-backend`（版本 `3.6.8`）。
2. 在 **RuoYi-Vue3** 手动运行 `release-frontend`（版本 `3.9.2`）。
3. 在 **RuoYi-Cloud** 手动运行 `build-images-backend`（版本 `3.6.8`）。
4. 在 **RuoYi-Vue3** 手动运行 `build-images-frontend`（版本 `3.9.2`）。
5. 在 **RuoYi-Cloud** 手动运行 `deploy-test`（版本 `3.6.8`），验证镜像拉取与全栈启动。

## 权限 / Secret

- `GITHUB_TOKEN`：GitHub 自动提供，已通过 `permissions:` 授予 `contents`/`packages` 写入权限；无需自管。
- 镜像默认在 `build-images-*` 中尽力设为**公开**（`gh api .../visibility public`），因此 `deploy-test` 可在另一仓库匿名拉取。若保持私有，需在运行 `deploy-test` 的仓库添加 `GHCR_PAT` 机密（值=有 `read:packages` 权限的令牌）并登录。

## 本地 / 服务器部署（Docker Compose）

```bash
# 仓库根目录
VERSION=3.6.8 docker compose -f cicd/docker-compose.yml up -d
# 冒烟测试
bash cicd/scripts/smoke-test.sh
```

说明：
- 业务镜像来自 `ghcr.io/zhuyifeiRuichuang/ruoyi-cloud/ruoyi-<svc>:<VERSION>`；前端来自 `ghcr.io/zhuyifeiRuichuang/ruoyi-vue3/ruoyi-web:<VERSION>`。
- MySQL 初始化脚本在 `cicd/sql/`（顺序：`00` Nacos 表结构 → `01` RuoYi Nacos 配置 → `02` 业务库 → `03` quartz）。
- **测试环境关闭了 Nacos 鉴权**（`NACOS_CORE_AUTH_ENABLED=false`），生产环境请开启并配置 `NACOS_AUTH_TOKEN`/`NACOS_AUTH_IDENTITY_*`。

## 标准 K8s 部署

`cicd/k8s/` 提供命名空间、中间件（MySQL/Redis/Nacos）、后端 7 服务与前端清单；`deploy-test` 的 kubernetes job 会自动用 kind 拉起集群并验证。`__VERSION__` 占位符在部署时被替换为实际版本。

## 说明 / 注意事项

- 数据库初始化拆分原因：`ry_config_20260918.sql` 自带 `DROP/CREATE DATABASE ry-config` 并在其中写入 Nacos 配置，因此 Nacos 必须连接 **ry-config** 库；业务库为 **ry-cloud**（两个库）。相应 SQL 已重排并剥离库的 DROP/CREATE 操作。
- 中间件镜像 `mysql:8.0` / `redis:7-alpine` 仅用于 amd64 测试（MySQL 5.7 无 arm64 镜像，且 Nacos 3.x 建议 MySQL 8）。
