# CRM 问卷系统 - 开发测试一体机 (main)
# Ubuntu 22.04 + JDK 1.8 + Maven + Tomcat 8.5 + 本机数据库 + 应用源码
# 一体机化: 应用和数据库都在这台机器上, 一个镜像一个容器跑完
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 时区老规矩, 东八区
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 内网软件源 (运维统一下发的 sources.list, 走清华)
RUN sed -i 's|archive.ubuntu.com|mirrors.tuna.tsinghua.edu.cn|g; s|security.ubuntu.com|mirrors.tuna.tsinghua.edu.cn|g' \
    /etc/apt/sources.list

# 构建期别让 apt 尝试起服务 (容器里没有 systemd)
RUN printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d

# JDK 1.8 headless (运维上周刚升级的版本; Web 应用不需要图形栈) + mariadb (本机库/查库验收)
# + curl (联调用; ubuntu 镜像不带, 必须显式装)
# 注意: 不用 apt 的 maven —— 它强依赖 default-jre-headless (= openjdk-11 的 42MB, 纯浪费)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       openjdk-8-jdk-headless mariadb-server mariadb-client curl \
    && rm -rf /var/lib/apt/lists/*
ENV JAVA_HOME_8=/usr/lib/jvm/java-8-openjdk-amd64
ENV JDK_VERSION=8

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

# Maven 3.6.3 (tarball 只认 JAVA_HOME, 不拖 default-jre 依赖; huaweicloud tarball)
ENV MAVEN_HOME=/usr/local/maven
ENV PATH=$MAVEN_HOME/bin:$PATH
RUN set -e; \
    url=https://repo.huaweicloud.com/apache/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz; \
    ok=0; \
    for i in 1 2 3 4 5; do \
        curl -4 -fSL -C - --connect-timeout 10 --max-time 180 -o /tmp/maven.tgz "$url" || true; \
        if gzip -t /tmp/maven.tgz 2>/dev/null; then ok=1; break; fi; \
        rm -f /tmp/maven.tgz; \
    done; \
    test "$ok" = "1"; \
    tar xzf /tmp/maven.tgz -C /usr/local; \
    ln -s /usr/local/apache-maven-3.6.3 /usr/local/maven

# 私服镜像 (aliyun), 中央仓库慢到哭的年代遗留
COPY maven-settings.xml /root/.m2/settings.xml

# Tomcat 8.5.9 (aliyun 仓库里的 tarball)
ENV CATALINA_HOME=/usr/local/tomcat
ENV PATH=$CATALINA_HOME/bin:$PATH
RUN set -e; \
    url=https://maven.aliyun.com/repository/public/org/apache/tomcat/tomcat/8.5.9/tomcat-8.5.9.tar.gz; \
    ok=0; \
    for i in 1 2 3 4 5; do \
        curl -4 -fSL -C - --connect-timeout 10 --max-time 180 -o /tmp/tomcat859.tgz "$url" || true; \
        if gzip -t /tmp/tomcat859.tgz 2>/dev/null; then ok=1; break; fi; \
        rm -f /tmp/tomcat859.tgz; \
    done; \
    test "$ok" = "1"; \
    tar xzf /tmp/tomcat859.tgz -C /usr/local; \
    ln -s /usr/local/apache-tomcat-8.5.9 /usr/local/tomcat; \
    rm -rf /usr/local/tomcat/webapps/*

# 库的字符集老配置: 中国区 utf8 (2006 年还没 utf8mb4 这东西)
RUN printf '[mysqld]\ncharacter-set-server=utf8\ncollation-server=utf8_general_ci\n' \
    > /etc/mysql/conf.d/charset.cnf

# 应用源码 (agent 的工作区就是它)
COPY crm-survey /opt/crm-survey
WORKDIR /opt/crm-survey

# 交付基线快照: 原始 src 原样存档, verifier 比对改动行数用。
# 基线放环境侧 (镜像内), 验证侧不持有与环境逐字节相同的资产
RUN mkdir -p /opt/.baseline && tar czf /opt/.baseline/src.tar.gz -C /opt crm-survey/src

# 构建期就把 war 打出来 (镜像一起来就能用, 别让评测等编译)
RUN mvn -B -q -DskipTests clean package

# 构建期就把 war 部署进 webapps (运行期换包即可, 不用从 target 拷)
RUN cp -f /opt/crm-survey/target/crm-survey.war $CATALINA_HOME/webapps/

# 数据库初始化全部在构建期: datadir (apt 安装时已初始化, 此处兜底) + 清匿名 + 建库/账号 + 种子
# (harbor 起容器是 run -d 即返, 运行期初始化会被 oracle/verifier 撞上车 —— 竞态;
#  构建期失败 = build 失败, 问题在镜像层就显形。重建容器 = datadir 回镜像层 = 数据重置)
# 匿名用户会按 host 优先匹配吃掉本机 TCP 连接, 把 crm@'%' 顶成 Access denied —— 必须清
RUN set -e; \
    [ -d /var/lib/mysql/mysql ] || mariadb-install-db --user=mysql --datadir=/var/lib/mysql >/dev/null 2>&1; \
    ( mysqld_safe --user=mysql >/dev/null 2>&1 & ); \
    for i in $(seq 1 60); do mysqladmin --silent ping >/dev/null 2>&1 && break; sleep 2; done; \
    mysql -e "DELETE FROM mysql.user WHERE user=''; FLUSH PRIVILEGES;"; \
    mysql -e "CREATE DATABASE IF NOT EXISTS crm_survey DEFAULT CHARACTER SET utf8; \
              CREATE USER 'crm'@'%' IDENTIFIED BY 'crm123'; \
              GRANT ALL PRIVILEGES ON crm_survey.* TO 'crm'@'%'; \
              FLUSH PRIVILEGES;"; \
    mysql < /opt/crm-survey/schema.sql; \
    mysql < /opt/crm-survey/init-admin.sql; \
    mysql -h127.0.0.1 -ucrm -pcrm123 crm_survey -N -s -e "SELECT COUNT(*) FROM sys_user;" | grep -q 3; \
    mysqladmin shutdown; \
    sleep 2

# 日志里中文别打问号
ENV JAVA_OPTS="-Dfile.encoding=UTF-8"

# 服务管理: deploy.sh 一键打包/部署/拉服务 (幂等), agent 与评测侧都调它;
# 容器主进程只做保活 (harbor 标准模式: run -d 即返, CMD 不干别的)
EXPOSE 8080 3306

CMD ["sleep", "100000000"]
