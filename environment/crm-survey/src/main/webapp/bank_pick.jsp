<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>从题库选入 - CRM 问卷系统</title>
    <style type="text/css">
        body { font-family: SimSun, serif; font-size: 12px; margin: 20px; }
        h3 { border-bottom: 1px solid #cccccc; padding-bottom: 4px; }
        table { border-collapse: collapse; }
        td { padding: 4px 8px; }
        form { display: inline; }
    </style>
</head>
<body>

<h3>标准题库 <span style="font-size: 12px; font-weight: normal;">(点"选入"把题目加进当前问卷)</span>
    <a style="float: right; font-size: 12px; font-weight: normal;" href="${pageContext.request.contextPath}/survey.do?method=questions&surveyId=${surveyId}">返回题目设置</a>
</h3>

<table border="1" cellspacing="0">
    <tr style="background: #eeeeee;">
        <td>ID</td>
        <td>题型</td>
        <td>题干</td>
        <td>操作</td>
    </tr>
    <c:forEach var="q" items="${questions}">
    <tr>
        <td>${q.id}</td>
        <td>
            <c:choose>
                <c:when test="${q.type == 1}">选择式</c:when>
                <c:otherwise>开放式</c:otherwise>
            </c:choose>
        </td>
        <td>${q.text}</td>
        <td>
            <form action="${pageContext.request.contextPath}/survey.do?method=pickBank" method="post">
                <input type="hidden" name="csrfToken" value="${sessionScope.CSRF_TOKEN}"/>
                <input type="hidden" name="surveyId" value="${surveyId}"/>
                <input type="hidden" name="questionId" value="${q.id}"/>
                <a href="javascript:void(0)" onclick="this.parentNode.submit()">选入</a>
            </form>
        </td>
    </tr>
    </c:forEach>
</table>

</body>
</html>
