---
name: crm-deploy
description: 一键编译并重新部署 CRM 问卷系统到 WSL talents-ai（Maven 打 war → deploy/ → 重启 Tomcat），可选完整重建（重置数据库），并验证页面可访问。
---

# CRM 问卷系统一键部署

项目路径固定在 Windows 的 `C:\wp\beat-llm-001`，WSL 发行版为 `talents-ai`。
以下命令都在 **Windows PowerShell** 里直接复制执行。

## 日常部署（保留数据库）

改完 Java/JSP 后使用。重新打 war，重启 app 容器；`crm-mysql` 不动，数据保留。

```powershell
wsl -d talents-ai -- bash -lc 'cd /mnt/c/wp/beat-llm-001/environment/crm-survey && ./build.sh && cd /mnt/c/wp/beat-llm-001/environment && docker compose restart app'
```

## 完整重建（会重置数据库）

改了 `schema.sql`、`init-admin.sql`、Dockerfile 或 compose 时使用。
`down` 后重建容器，MySQL 会重新执行 `schema.sql` 和 `zz-init-admin.sql`，数据全部重置。

```powershell
wsl -d talents-ai -- bash -lc 'cd /mnt/c/wp/beat-llm-001/environment/crm-survey && ./build.sh && cd /mnt/c/wp/beat-llm-001/environment && docker compose down && docker compose up -d --build'
```

## 切换 JDK（7/8 对比测试）

app 镜像同时装了 JDK 1.7.0_80 和 JDK 1.8，切换只重建容器，不重建镜像。war 用 `source/target 1.7` 编译，两个 JDK 都能运行。

```powershell
# 切到 JDK 7
wsl -d talents-ai -- bash -lc 'cd /mnt/c/wp/beat-llm-001/environment && JDK_VERSION=7 docker compose up -d --no-build --force-recreate app'

# 切到 JDK 8
wsl -d talents-ai -- bash -lc 'cd /mnt/c/wp/beat-llm-001/environment && JDK_VERSION=8 docker compose up -d --no-build --force-recreate app'
```

查看当前 JDK：

```powershell
wsl -d talents-ai -- bash -lc 'docker logs crm-tomcat 2>&1 | grep "使用 JDK"'
```

`docker compose restart app` 不会改变已注入的环境变量，必须用上面的 `up -d --force-recreate`。

## 部署后验证

```powershell
wsl -d talents-ai -- bash -lc 'cd /mnt/c/wp/beat-llm-001/environment && docker compose ps && curl -s -I http://localhost:8080/crm-survey/login.jsp | head -1'
```

预期：`crm-mysql`、`crm-tomcat` 都是 `Up`，HTTP 返回 `200`。
浏览器入口：http://localhost:8080/crm-survey/login.jsp （zhangsan / 123456，admin / admin123）。

## 说明与排障

- `build.sh` 会先构建 `crm-builder` 镜像，再把源码挂进容器执行 `mvn package`，产物复制到 `environment/crm-survey/deploy/crm-survey.war`；该目录挂载为 Tomcat 的 `webapps`。
- 首次构建或依赖变化时较慢；之后主要耗时在 Maven 下载。
- `vault.centos.org` 在本机返回 403，两个 Dockerfile 已改用 aliyun 的 `centos-vault` 镜像；同时显式设置了 `JAVA_HOME`，不要删。
- 如果本机没有 `mysql:5.7` 镜像且 Docker Hub 拉取很慢，先走镜像源：
  ```powershell
  wsl -d talents-ai -- bash -lc 'docker pull docker.m.daocloud.io/library/mysql:5.7 && docker tag docker.m.daocloud.io/library/mysql:5.7 mysql:5.7'
  ```
- 数据库宿主机端口是 `8306`（容器内 3306），账号 `crm/crm123`，root 密码 `root123`。
- 只重启 app 不会重跑数据库初始化；需要重置数据就用「完整重建」。
- 不要进入 app 容器执行操作；看日志用 `docker logs -f crm-tomcat`。

## 被调用时 Claude 的执行方式

1. 用 PowerShell 工具执行对应的部署命令（默认选「日常部署」；用户明确要求重置数据时选「完整重建」）。
2. 等待命令退出码为 0；构建失败时贴出最后 30 行错误并停止。
3. 执行「部署后验证」，确认两个容器 Up 且登录页返回 200。
4. 简短汇报部署结果和访问入口。
