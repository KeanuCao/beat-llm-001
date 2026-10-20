# CRM 问卷系统 - 应用镜像 (生产机)
# CentOS 7 + JDK 1.7 + Tomcat 8.5
# 老架构三机分离: builder 编译 / app 跑应用 / db 放数据
# 产线上只有运行时, 没有 maven —— 编译是构建机的事
FROM centos:7

MAINTAINER ops <ops@company.com>

# 时区老规矩, 东八区
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# CentOS 7 已经停止维护, yum 源切到 vault 归档 (走 aliyun 镜像)
RUN sed -i -e 's|^mirrorlist=|#mirrorlist=|g' \
           -e 's|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.aliyun.com/centos-vault|g' \
           /etc/yum.repos.d/CentOS-*.repo

# JDK 1.7.0_80 (Oracle 7u80 tarball, 留全量 JDK, 线上排障要用 jstack/jmap)
ENV JAVA_HOME_7=/usr/local/jdk1.7.0_80
ENV JAVA_HOME=/usr/local/jdk1.7.0_80
ENV PATH=$JAVA_HOME/bin:$PATH
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
    rm -f /tmp/jdk7u80.tar.gz; \
    java -version

# JDK 1.8 与 1.7 并存, 容器启动时按 JDK_VERSION 选择 (对比测试不用重建镜像)
RUN yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel \
    && yum clean all && rm -rf /var/cache/yum
ENV JAVA_HOME_8=/usr/lib/jvm/java-1.8.0-openjdk
ENV JDK_VERSION=7

# JDK 7u80 自带 cacerts 是 2015 年的, 126 证书链校验失败; 用 JDK 8 的现代信任库覆盖
RUN cp -L /usr/lib/jvm/java-1.8.0-openjdk/jre/lib/security/cacerts \
          /usr/local/jdk1.7.0_80/jre/lib/security/cacerts

# Tomcat 8.5, tarball 解压部署, 老规矩
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
    rm -f /tmp/tomcat859.tgz; \
    ln -s /usr/local/apache-tomcat-8.5.9 /usr/local/tomcat; \
    rm -rf /usr/local/tomcat/webapps/*

# 数据库连接信息 (jdbc 配置后面从这里取)
ENV DB_HOST=db
ENV DB_PORT=3306

COPY app/start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
