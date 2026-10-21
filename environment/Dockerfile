# CRM 问卷系统 - 开发测试一体机 (main)
# CentOS 7 + JDK 1.8 + Maven + Tomcat 8.5 + 本机数据库 + 应用源码
# 一体机化: 应用和数据库都在这台机器上, 一个镜像一个容器跑完
FROM centos:7

MAINTAINER crm-dev <crm-dev@company.com>

# 时区老规矩, 东八区
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# CentOS 7 已经停止维护, yum 源切到 vault 归档 (走 aliyun 镜像)
RUN sed -i -e 's|^mirrorlist=|#mirrorlist=|g' \
           -e 's|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.aliyun.com/centos-vault|g' \
           /etc/yum.repos.d/CentOS-*.repo

# JDK 1.8 (运维上周刚升级的版本) + mariadb-server (本机库) + 客户端 (查库验收用) + which (mvn 要用)
RUN yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel mariadb-server mariadb which \
    && yum clean all && rm -rf /var/cache/yum
ENV JAVA_HOME_8=/usr/lib/jvm/java-1.8.0-openjdk
ENV JDK_VERSION=8

ENV JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
ENV PATH=$JAVA_HOME/bin:$PATH

# Maven 3.3.9 (一体机上构建, huaweicloud tarball)
ENV MAVEN_HOME=/usr/local/maven
ENV PATH=$MAVEN_HOME/bin:$PATH
RUN set -e; \
    url=https://repo.huaweicloud.com/apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz; \
    ok=0; \
    for i in 1 2 3 4 5; do \
        curl -4 -fSL -C - --connect-timeout 10 --max-time 180 -o /tmp/maven.tgz "$url" || true; \
        if gzip -t /tmp/maven.tgz 2>/dev/null; then ok=1; break; fi; \
        rm -f /tmp/maven.tgz; \
    done; \
    test "$ok" = "1"; \
    tar xzf /tmp/maven.tgz -C /usr/local; \
    ln -s /usr/local/apache-maven-3.3.9 /usr/local/maven

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
# (RHEL 系的 my.cnf 不含 my.cnf.d 的 include, 直接追加主文件; 追加同名段按合并语义生效)
RUN printf '\n[mysqld]\ncharacter-set-server=utf8\ncollation-server=utf8_general_ci\n' \
    >> /etc/my.cnf

# 应用源码 (agent 的工作区就是它)
COPY crm-survey /opt/crm-survey
WORKDIR /opt/crm-survey

# 交付基线快照: 原始 src 原样存档, verifier 比对改动行数用。
# 基线放环境侧 (镜像内), 验证侧不持有与环境逐字节相同的资产
RUN mkdir -p /opt/.baseline && tar czf /opt/.baseline/src.tar.gz -C /opt crm-survey/src

# 构建期就把 war 打出来 (镜像一起来就能用, 别让评测等编译)
RUN mvn -B -q -DskipTests clean package

# 日志里中文别打问号
ENV JAVA_OPTS="-Dfile.encoding=UTF-8"

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 8080 3306

# entrypoint: 初始化并拉起本机 db + 应用, 就绪后正常退出 (脚本本身无常驻进程);
# 保活由这里的 sleep 接管 (纯数字秒数, 老 coreutils 也认)
CMD ["/bin/bash", "-c", "/docker-entrypoint.sh && exec sleep 100000000"]
