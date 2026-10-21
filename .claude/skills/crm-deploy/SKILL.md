---
name: crm-deploy
description: CRM 问卷系统的编译/部署速查（harbor 版一体机布局：main = 开发测试一体机，db = 侧车）。
---

# CRM 问卷系统部署速查

布局：`main` 服务 = 开发测试一体机（源码在 `/opt/crm-survey`，Maven/Tomcat 都在本机），
`db` 服务 = MySQL 5.7（编排网络内 `db:3306`）。平台禁用 `ports`/`container_name`
（compose 白名单键），服务名就是 db/main，别再用 crm-mysql/crm-main 容器名，
宿主机查库: `docker compose exec db mysql -ucrm -pcrm123 crm_survey`。
保活模型：`docker-entrypoint.sh` 是纯启动脚本（就绪轮询后正常退出，过平台脚本检查），PID1 由 compose 的 `command`（`&& exec sleep infinity`）
接管；PID1 不是 Tomcat，所以容器内照旧可以 `catalina.sh stop/start` 换包。

## 部署（改完 Java/JSP 后，在 WSL 里）

```bash
wsl -d talents-ai -- bash -lc 'docker exec crm-main bash -lc "cd /opt/crm-survey && mvn -B -q -DskipTests package && cp -f target/crm-survey.war \$CATALINA_HOME/webapps/ && \$CATALINA_HOME/bin/catalina.sh stop >/dev/null 2>&1; sleep 2; \$CATALINA_HOME/bin/startup.sh"'
```

## 完整重建（重置数据库：改了 schema/init-admin/Dockerfile/compose 时）

```bash
cd /mnt/c/wp/beat-llm-001/environment && docker compose down && docker compose up -d --build
```

## 验证

```bash
docker compose ps && curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/crm-survey/login.jsp
```

预期：两个容器 Up，登录页 200（zhangsan/123456，admin/admin123）。

## 排障

- 日志：宿主机 `docker logs crm-main`，或容器内 `$CATALINA_HOME/logs/catalina.out`
- mysql:5.7 拉不动走 `docker.m.daocloud.io/library/mysql:5.7` 再 retag
- 数据库宿主机端口 8306（容器内 3306），账号 crm/crm123，root 密码 root123
- 邮件配置：`src/main/resources/mail.properties` 不入库，从 template 复制填真值；没有它发信失败但邀请照常生成
