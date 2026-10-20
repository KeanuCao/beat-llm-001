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

# JDK 1.8
RUN yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel \
    && yum clean all && rm -rf /var/cache/yum
ENV JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk

# Maven 3.3.9 (2015 年的老版本, 解压即用)
ENV MAVEN_HOME=/usr/local/maven
ENV PATH=$MAVEN_HOME/bin:$PATH
RUN curl -fsSL https://archive.apache.org/dist/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz \
    | tar xz -C /usr/local \
 && ln -s /usr/local/apache-maven-3.3.9 /usr/local/maven

# 私服镜像配置 (当年 aliyun 的老地址早改版了, 这里用新地址)
COPY settings.xml /root/.m2/settings.xml

# 源码从外面挂进来, 挂到 /build 里编译
WORKDIR /build
CMD ["mvn", "-B", "-DskipTests", "package"]
