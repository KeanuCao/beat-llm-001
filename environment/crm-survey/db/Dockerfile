# CRM 问卷系统 - 数据库镜像
# MySQL 5.7 官方镜像 + 建库脚本
# 老架构: 应用和数据库分开部署, 数据库不跑业务机器
FROM mysql:5.7

MAINTAINER dba <dba@company.com>

# 时区
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 建库脚本, 官方镜像首次启动会自动执行 /docker-entrypoint-initdb.d/ 下的脚本
COPY schema.sql /docker-entrypoint-initdb.d/schema.sql
# 超级管理员初始化, 99- 前缀保证排在 schema.sql 之后执行
COPY init-admin.sql /docker-entrypoint-initdb.d/99-init-admin.sql

# 中国区老项目标配 utf8 (别问为什么不是 utf8mb4, 2006 年还没这东西)
CMD ["--character-set-server=utf8", "--collation-server=utf8_general_ci"]

EXPOSE 3306
