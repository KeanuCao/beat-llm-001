#!/bin/bash
# ============================================================
# crm-survey 一键部署脚本 (运维组标准脚本, 幂等, 重复执行安全)
# 用法: bash /opt/crm-survey/deploy.sh
#   1) 编译当前源码并打包 war
#   2) 部署到 Tomcat 并重启应用 (重复执行 = 重新部署当前源码)
#   3) 确保本机数据库 mysqld 在运行 (部署不动库, 数据不丢)
#   4) 应用与数据库都就绪才退出, 任何一步失败非 0 退出
# ============================================================
set -e

export JAVA_HOME=${JAVA_HOME_8:-/usr/lib/jvm/java-8-openjdk-amd64}
export PATH="$JAVA_HOME/bin:$PATH"

# 1) 打包当前源码
cd /opt/crm-survey
mvn -B -q -DskipTests clean package

# 2) 换包 + 重启应用
$CATALINA_HOME/bin/catalina.sh stop >/dev/null 2>&1 || true
sleep 2
rm -rf $CATALINA_HOME/webapps/crm-survey
cp -f target/crm-survey.war $CATALINA_HOME/webapps/
$CATALINA_HOME/bin/catalina.sh start >/dev/null 2>&1

# 3) 数据库: 拉起服务 (幂等); 首次使用时建库+种子 (建过就不动, 重复部署不重置数据)
if ! mysqladmin --silent ping >/dev/null 2>&1; then
    service mariadb start >/dev/null 2>&1 \
        || service mysql start >/dev/null 2>&1 \
        || { echo ">>> mysqld 起不来, 看 /var/log/mysql/error.log"; exit 1; }
fi
DB_OK=""
for i in $(seq 1 90); do
    if mysqladmin --silent ping >/dev/null 2>&1; then DB_OK=1; break; fi
    sleep 2
done
[ -n "$DB_OK" ] || { echo ">>> 数据库起不来, 看 /var/log/mysql/error.log"; exit 1; }
if [ ! -d /var/lib/mysql/crm_survey ]; then
    echo ">>> 数据库首次初始化: 建库 / 账号 / 种子数据..."
    mysql -e "DELETE FROM mysql.user WHERE user=''; FLUSH PRIVILEGES;" \
        || { echo ">>> 清理匿名用户失败"; exit 1; }
    mysql -e "CREATE DATABASE IF NOT EXISTS crm_survey DEFAULT CHARACTER SET utf8; \
              CREATE USER IF NOT EXISTS 'crm'@'%' IDENTIFIED BY 'crm123'; \
              GRANT ALL PRIVILEGES ON crm_survey.* TO 'crm'@'%'; \
              FLUSH PRIVILEGES;" || { echo ">>> 建库/建号失败"; exit 1; }
    mysql < /opt/crm-survey/schema.sql || { echo ">>> schema 导入失败"; exit 1; }
    mysql < /opt/crm-survey/init-admin.sql || { echo ">>> 管理员种子导入失败"; exit 1; }
fi
mysql -h127.0.0.1 -ucrm -pcrm123 crm_survey -N -s -e "SELECT 1;" >/dev/null 2>&1 \
    || { echo ">>> crm 账号连不上 (数据目录异常?), 考虑重建容器"; exit 1; }

# 4) 应用就绪轮询
CODE=""
for i in $(seq 1 45); do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/crm-survey/login.jsp || true)
    [ "$CODE" = "200" ] && break
    sleep 2
done
[ "$CODE" = "200" ] || { echo ">>> 应用未就绪, 看日志: $CATALINA_HOME/logs/catalina.out"; exit 1; }

echo ">>> 部署完成: 应用 8080 / 数据库 3306 均就绪"
exit 0
