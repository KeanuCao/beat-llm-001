---
name: crm-deploy
description: CRM 问卷系统的编译/部署/本地测试速查（单容器一体机：应用+本机数据库一个 Dockerfile，compose 已弃用）。
---

# CRM 问卷系统部署速查

布局：**单容器**（`environment/Dockerfile` 一体机）= Ubuntu 22.04 + JDK 1.8 (openjdk-8-jdk,
apt) + Maven (apt) + Tomcat 8.5.9 (tarball) + mariadb-server 10.6（本机库，构建期已初始化
建库导种子）+ 源码 `/opt/crm-survey`。**与沙箱同构**（同样的 ubuntu/apt/mariadb 10.6 组合）。
应用配置 `jdbc.properties` 连 `localhost:3306`。compose 已弃用删除（平台键白名单坑多，
详见 harbor-submit skill 第 1 节）。

## 本地完整演练（等价平台 oracle 流程）

```bash
cd environment
docker build -t crm-survey-main .

# 容器名固定 crm-main —— solve.sh 的宿主机分支写死了它, 别换名字
# CMD 是纯保活(sleep), 服务不起 —— solve/verifier 自己调 deploy.sh 拉起
docker run -d --name crm-main crm-survey-main

# oracle: 参考解进容器执行 (内部调用 deploy.sh 拉起服务)
docker cp ../solution crm-main:/opt/solution
docker exec crm-main bash /opt/solution/solve.sh

# verifier: 评测脚本进容器执行 (与平台一致, 容器内路径)
docker cp ../tests crm-main:/opt/tests
docker exec crm-main bash /opt/tests/test.sh
docker exec crm-main cat /logs/verifier/reward.txt    # 期望 1
```

## 改完 Java/JSP 后快速重部署（容器内，幂等）

```bash
docker exec crm-main bash /opt/crm-survey/deploy.sh
# = 编译 -> 打 war -> 部署重启应用 -> 确保 mysqld 在跑 -> 等就绪
```

PID1 是 sleep 不是 Tomcat, 容器内 stop/start 换包安全。

## 完整重建（重置数据库：改了 schema/init-admin/Dockerfile 时）

```bash
cd environment && docker rm -f crm-main; docker build -t crm-survey-main . && docker run -d --name crm-main crm-survey-main
```

重建容器 = datadir 归零 = 首启重新初始化导种子（数据重置语义）。

## 验证

```bash
docker exec crm-main curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/crm-survey/login.jsp  # 200
docker exec crm-main mysql -h127.0.0.1 -ucrm -pcrm123 crm_survey -e "SELECT COUNT(*) FROM survey_question;"
```

预期：登录页 200（zhangsan/123456，admin/admin123），11 张表。

## 排障

- 日志：容器内 `$CATALINA_HOME/logs/catalina.out`，或 `docker logs crm-main`
- mysqld 起不来：进容器看 `/var/log/mysql/error.log` 与 `ls -la /var/lib/mysql`
- 库账号 crm/crm123，root 走本地 socket unix_socket 认证（`docker exec crm-main mysql -uroot crm_survey`）
- 邮件配置：`src/main/resources/mail.properties` 不入库，从 template 复制填真值；没有它发信失败但邀请照常生成
- 基础镜像换了 ubuntu 后冷构建快很多（apt aliyun 活跃源 vs centos vault 归档源 ~160KB/s 的教训）
