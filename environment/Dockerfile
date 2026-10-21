# CRM 问卷系统 - 开发测试一体机 (main)
# CentOS 7 + JDK 1.7/1.8 + Maven + Tomcat 8.5 + 应用源码
# 当年小公司的常态: 一台机器既是开发机又是应用机, 数据库另放一台
FROM centos:7

MAINTAINER crm-dev <crm-dev@company.com>

# 时区老规矩, 东八区
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# CentOS 7 已经停止维护, yum 源切到 vault 归档 (走 aliyun 镜像)
RUN sed -i -e 's|^mirrorlist=|#mirrorlist=|g' \
           -e 's|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.aliyun.com/centos-vault|g' \
           /etc/yum.repos.d/CentOS-*.repo

# JDK 1.7.0_80 (产线原版, huaweicloud 的 tarball + 断点续传重试)
ENV JAVA_HOME_7=/usr/local/jdk1.7.0_80
RUN set -e; \
    url=https://repo.huaweicloud.com/java/jdk/7u80-b15/jdk-7u80-linux-x64.tar.gz; \
    ok=0; \
    for i in 1 2 3 4 5 6 7 8; do \
        curl -fSL -C - -o /tmp/jdk7u80.tar.gz "$url" || true; \
        if gzip -t /tmp/jdk7u80.tar.gz 2>/dev/null; then ok=1; break; fi; \
        rm -f /tmp/jdk7u80.tar.gz; \
    done; \
    test "$ok" = "1"; \
    tar xzf /tmp/jdk7u80.tar.gz -C /usr/local; \
    rm -f /tmp/jdk7u80.tar.gz

# JDK 1.8 (运维升级后的版本) + mariadb 客户端 (查库验收用) + which (mvn 要用)
RUN yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel mariadb which \
    && yum clean all && rm -rf /var/cache/yum
ENV JAVA_HOME_8=/usr/lib/jvm/java-1.8.0-openjdk
ENV JDK_VERSION=8

# 构建期先用 JDK 8 (运行期由 entrypoint 按 JDK_VERSION 重选)
ENV JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
ENV PATH=$JAVA_HOME/bin:$PATH

# JDK 7u80 自带 cacerts 是 2015 年的, 126 证书链校验失败; 用 JDK 8 的现代信任库覆盖
RUN cp -L /usr/lib/jvm/java-1.8.0-openjdk/jre/lib/security/cacerts \
          /usr/local/jdk1.7.0_80/jre/lib/security/cacerts

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

# 应用源码 (agent 的工作区就是它)
COPY crm-survey /opt/crm-survey
WORKDIR /opt/crm-survey

# 交付基线快照: 原始 src 原样存档, verifier 比对改动行数用。
# 基线放环境侧 (镜像内), 验证侧不持有与环境逐字节相同的资产
RUN mkdir -p /opt/.baseline && tar czf /opt/.baseline/src.tar.gz -C /opt crm-survey/src

# 构建期就把 war 打出来 (镜像一起来就能用, 别让评测等编译)
RUN mvn -B -q -DskipTests clean package

# 数据库在另一台"机器"上
ENV DB_HOST=db
ENV DB_PORT=3306

# 日志里中文别打问号
ENV JAVA_OPTS="-Dfile.encoding=UTF-8"

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 8080

CMD ["/docker-entrypoint.sh"]
