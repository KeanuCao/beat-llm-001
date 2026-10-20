<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>问卷管理 - CRM 问卷系统</title>
    <style type="text/css">
        body { font-family: SimSun, serif; font-size: 12px; margin: 20px; }
        h3 { border-bottom: 1px solid #cccccc; padding-bottom: 4px; }
        table { border-collapse: collapse; }
        td { padding: 4px 8px; }
        .msg { color: red; }
        form { display: inline; }
    </style>
</head>
<body>

<h3>问卷管理</h3>
<div class="msg">${msg}</div>

<div style="margin: 8px 0;">
    <a href="${pageContext.request.contextPath}/survey.do?method=edit">新建问卷</a>
</div>

<table border="1" cellspacing="0">
    <tr style="background: #eeeeee;">
        <td>ID</td>
        <td>标题</td>
        <td>说明</td>
        <td>状态</td>
        <td>发布时间</td>
        <td>创建时间</td>
        <td>操作</td>
    </tr>
    <c:forEach var="s" items="${surveys}">
    <tr>
        <td>${s.id}</td>
        <td><a href="${pageContext.request.contextPath}/survey.do?method=questions&surveyId=${s.id}">${s.title}</a></td>
        <td>${s.description}</td>
        <td>
            <c:choose>
                <c:when test="${s.status == 0}">草稿</c:when>
                <c:when test="${s.status == 1}">已发布</c:when>
                <c:otherwise>已下线</c:otherwise>
            </c:choose>
        </td>
        <td><fmt:formatDate value="${s.publishTime}" pattern="yyyy-MM-dd HH:mm"/></td>
        <td><fmt:formatDate value="${s.createTime}" pattern="yyyy-MM-dd HH:mm"/></td>
        <td>
            <a href="${pageContext.request.contextPath}/survey.do?method=edit&id=${s.id}">编辑</a>
            <a href="${pageContext.request.contextPath}/survey.do?method=questions&surveyId=${s.id}">题目设置</a>
            <c:if test="${s.status != 1}">
            <form action="${pageContext.request.contextPath}/survey.do?method=start" method="post">
                <input type="hidden" name="csrfToken" value="${sessionScope.CSRF_TOKEN}"/>
                <input type="hidden" name="surveyId" value="${s.id}"/>
                <button type="submit">发布问卷</button>
            </form>
            </c:if>
            <form action="${pageContext.request.contextPath}/survey.do?method=delete" method="post">
                <input type="hidden" name="csrfToken" value="${sessionScope.CSRF_TOKEN}"/>
                <input type="hidden" name="id" value="${s.id}"/>
                <a href="javascript:void(0)" onclick="this.parentNode.submit()">删除</a>
            </form>
        </td>
    </tr>
    </c:forEach>
</table>

</body>
</html>
