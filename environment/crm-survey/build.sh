#!/bin/bash
# 一键编译: 在 builder 容器里打 war 包, 产物放进 ./deploy
# 当年这活儿是构建机 (或后来的 Jenkins) 干的, 这里用容器模拟一台构建机
# 用法: ./build.sh   (产物出来后 docker-compose up -d 即可部署)

set -e
cd "$(dirname "$0")"

echo ">>> 构建 builder 镜像..."
docker build -t crm-builder -f builder/Dockerfile builder/

echo ">>> 源码挂进 builder, 开始编译..."
docker run --rm -v "$PWD":/build crm-builder

mkdir -p deploy
cp target/crm-survey.war deploy/crm-survey.war
echo ">>> war 已放到 deploy/crm-survey.war, Tomcat 会自动部署"
