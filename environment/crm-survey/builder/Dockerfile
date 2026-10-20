# CRM 问卷系统 - 编译机镜像 (builder)
# 当年的分工: 编译在构建机/CI 机上做, war 包再发到产线, 产线上不装 maven
FROM centos:7

MAINTAINER ci <ci@company.com>

# 时区
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# CentOS 7 已经停止维护, yum 源切到 vault 归档 (走 aliyun 镜像)
RUN sed -i -e 's|^mirrorlist=|#mirrorlist=|g' \
           -e 's|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.aliyun.com/centos-vault|g' \
           /etc/yum.repos.d/CentOS-*.repo

# JDK 1.7.0_80 (Oracle 7u80 tarball, 对应当年产线 JDK 7)
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

# JDK 7 默认 TLS 版本较老, Maven 走 aliyun HTTPS 时钉 1.2
ENV MAVEN_OPTS="-Dhttps.protocols=TLSv1.2"

# Maven 3.3.9 (2015 年的老版本, 解压即用)
ENV MAVEN_HOME=/usr/local/maven
ENV PATH=$MAVEN_HOME/bin:$PATH
RUN set -e; \
    url=https://repo.huaweicloud.com/apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz; \
    ok=0; \
    for i in 1 2 3 4 5; do \
        curl -4 -fSL -C - --connect-timeout 10 --max-time 120 -o /tmp/maven.tgz "$url" || true; \
        if gzip -t /tmp/maven.tgz 2>/dev/null; then ok=1; break; fi; \
        rm -f /tmp/maven.tgz; \
    done; \
    test "$ok" = "1"; \
    tar xzf /tmp/maven.tgz -C /usr/local; \
    rm -f /tmp/maven.tgz; \
    ln -s /usr/local/apache-maven-3.3.9 /usr/local/maven

# 私服镜像配置 (当年 aliyun 的老地址早改版了, 这里用新地址)
COPY settings.xml /root/.m2/settings.xml

# 源码从外面挂进来, 挂到 /build 里编译
WORKDIR /build
CMD ["mvn", "-B", "-DskipTests", "clean", "package"]
