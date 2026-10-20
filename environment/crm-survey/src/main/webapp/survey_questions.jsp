<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>题目设置 - CRM 问卷系统</title>
    <style type="text/css">
        body { font-family: SimSun, serif; font-size: 12px; margin: 20px; }
        h3 { border-bottom: 1px solid #cccccc; padding-bottom: 4px; }
        table { border-collapse: collapse; }
        td { padding: 4px 8px; }
        .msg { color: red; }
        .err { color: red; }
    </style>
</head>
<body>

<h3>
    题目设置 - ${survey.title}
    <c:choose>
        <c:when test="${survey.status == 1}"> (已发布 <fmt:formatDate value="${survey.publishTime}" pattern="yyyy-MM-dd HH:mm"/>)</c:when>
        <c:when test="${survey.status == 2}"> (已下线)</c:when>
        <c:otherwise> (草稿)</c:otherwise>
    </c:choose>
    <a style="float: right; font-size: 12px; font-weight: normal;" href="${pageContext.request.contextPath}/survey.do?method=list">返回列表</a>
</h3>
<div class="msg">${msg}</div>

<div style="margin: 8px 0;">
    <a href="${pageContext.request.contextPath}/survey.do?method=pickPage&surveyId=${survey.id}">从标准题库选入</a>
    <c:if test="${survey.status != 1}">
        <form action="${pageContext.request.contextPath}/survey.do?method=start" method="post" style="display: inline;">
            <input type="hidden" name="csrfToken" value="${sessionScope.CSRF_TOKEN}"/>
            <input type="hidden" name="surveyId" value="${survey.id}"/>
            <button type="submit">开始调查</button>
        </form>
    </c:if>
    <c:if test="${survey.status == 1}">
        <a href="${pageContext.request.contextPath}/survey.do?method=run&surveyId=${survey.id}">进入调查页</a>
    </c:if>
</div>

<table border="1" cellspacing="0">
    <tr style="background: #eeeeee;">
        <td>排序</td>
        <td>题型</td>
        <td>题干</td>
        <td>选项</td>
    </tr>
    <c:forEach var="q" items="${questions}">
    <tr>
        <td>${q.sort}</td>
        <td>
            <c:choose>
                <c:when test="${q.type == 1}">选择式</c:when>
                <c:otherwise>开放式</c:otherwise>
            </c:choose>
        </td>
        <td>${q.text}</td>
        <td>
            <c:forEach var="opt" items="${q.answers}" varStatus="st">${st.index > 0 ? '<br/>' : ''}${opt.content}</c:forEach>
            <c:if test="${q.type == 2}">(自由作答)</c:if>
        </td>
    </tr>
    </c:forEach>
    <c:if test="${empty questions}">
    <tr><td colspan="4">还没有题目, 从上面选入或添加</td></tr>
    </c:if>
</table>

<h3 style="margin-top: 24px;">添加自定义题目</h3>
<div class="err">${errorMsg}</div>
<%-- 走老的配置保存链路 (surveyConfig.do), 嵌套参数原样提交 --%>
<form action="${pageContext.request.contextPath}/surveyConfig.do" method="post">
    <input type="hidden" name="csrfToken" value="${sessionScope.CSRF_TOKEN}"/>
    <input type="hidden" name="id" value="${survey.id}"/>
    <input type="hidden" name="surveyName" value="${survey.title}"/>
    <input type="hidden" name="questions[0].id" value="0"/>
    <input type="hidden" name="questions[0].sort" value="${nextSort}"/>
    <input type="hidden" name="questions[0].answers[0].id" value="0"/>
    <input type="hidden" name="questions[0].answers[1].id" value="0"/>
    <input type="hidden" name="questions[0].answers[2].id" value="0"/>
    <table>
        <tr>
            <td>题型:</td>
            <td>
                <select name="questions[0].type">
                    <option value="1">单选</option>
                    <option value="2">多选</option>
                    <option value="3">开放式</option>
                </select>
            </td>
        </tr>
        <tr>
            <td>题干:</td>
            <td><input type="text" name="questions[0].text" size="60" maxlength="1000"/></td>
        </tr>
        <tr>
            <td>选项:</td>
            <td>
                <input type="text" name="questions[0].answers[0].content" size="25"/>
                <input type="text" name="questions[0].answers[1].content" size="25"/>
                <input type="text" name="questions[0].answers[2].content" size="25"/>
                (开放式不用填)
            </td>
        </tr>
        <tr>
            <td colspan="2"><input type="submit" value=" 添加题目 "/></td>
        </tr>
    </table>
</form>

</body>
</html>
