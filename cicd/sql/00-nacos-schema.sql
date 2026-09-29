/* Auto-generated: ensure ry-config DB exists.
 *
 * 这里只建库，不再建表：Nacos 表结构统一由 01-ry-config.sql 提供。
 *
 * 原因：01-ry-config.sql 是 Nacos 实例导出的配置库，自带完整 schema 与 config_info 数据，
 * 且表集合是此处原 Nacos schema 的严格超集（01 有 16 张表 ⊇ 原有的 10 张表；
 * config_info / his_config_info / tenant_info 的列定义逐列一致）。
 * 此前本文件与 01 都会去建 config_info 等表，MySQL 初始化时报：
 *   ERROR 1050 (42S01) at line 8: Table 'config_info' already exists
 * 使 ruoyi-mysql 容器退出（exit 1），compose 与 k8s 两条部署路径均随之失败。
 */
CREATE DATABASE IF NOT EXISTS `ry-config` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `ry-config`;
