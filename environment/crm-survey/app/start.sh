#!/bin/bash
# 应用启动脚本: 先等数据库通, 再拉起 Tomcat
# 2016 年容器里没有 healthcheck, 探活就靠 bash 的 /dev/tcp 小把戏

set -e

DB_HOST=${DB_HOST:-db}
DB_PORT=${DB_PORT:-3306}

echo ">>> 等待数据库 $DB_HOST:$DB_PORT ..."
until (echo > /dev/tcp/$DB_HOST/$DB_PORT) 2>/dev/null; do
    echo "    数据库还没起来, 再等等..."
    sleep 2
done
echo ">>> 数据库已就绪"

echo ">>> 启动 Tomcat 8.5, 端口 8080 (war 包从 webapps 挂载目录自动部署)"
exec $CATALINA_HOME/bin/catalina.sh run
