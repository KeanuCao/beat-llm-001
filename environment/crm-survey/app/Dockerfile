# CRM 问卷系统 - 应用镜像 (生产机)
# CentOS 7 + JDK 1.8 + Tomcat 8.5
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

# JDK 1.8 (留全量 JDK, 线上排障要用 jstack/jmap)
RUN yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel \
    && yum clean all && rm -rf /var/cache/yum
ENV JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk

# Tomcat 8.5, tarball 解压部署, 老规矩
ENV CATALINA_HOME=/usr/local/tomcat
ENV PATH=$CATALINA_HOME/bin:$PATH
RUN curl -fsSL https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.9/bin/apache-tomcat-8.5.9.tar.gz \
    | tar xz -C /usr/local \
 && ln -s /usr/local/apache-tomcat-8.5.9 /usr/local/tomcat \
 && rm -rf $CATALINA_HOME/webapps/*

# 数据库连接信息 (jdbc 配置后面从这里取)
ENV DB_HOST=db
ENV DB_PORT=3306

COPY app/start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
