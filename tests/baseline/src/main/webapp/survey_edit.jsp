<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>问卷编辑 - CRM 问卷系统</title>
    <style type="text/css">
        body { font-family: SimSun, serif; font-size: 12px; margin: 20px; }
        h3 { border-bottom: 1px solid #cccccc; padding-bottom: 4px; }
        td { padding: 4px 6px; }
        .err { color: red; }
    </style>
</head>
<body>

<h3>${empty survey ? '新建问卷' : '编辑问卷'}</h3>
<div class="err">${errorMsg}</div>

<form action="${pageContext.request.contextPath}/survey.do?method=save" method="post">
    <input type="hidden" name="csrfToken" value="${sessionScope.CSRF_TOKEN}"/>
    <input type="hidden" name="id" value="${empty survey ? 0 : survey.id}"/>

    <table>
        <tr>
            <td>标题:</td>
            <td><input type="text" name="title" value="${survey.title}" size="50" maxlength="200"/></td>
        </tr>
        <tr>
            <td>说明:</td>
            <td><textarea name="description" rows="4" cols="60">${survey.description}</textarea></td>
        </tr>
        <tr>
            <td colspan="2" align="center"><input type="submit" value=" 保存并设置题目 "/></td>
        </tr>
    </table>
</form>

<div style="margin-top: 12px;">
    <a href="${pageContext.request.contextPath}/survey.do?method=list">返回列表</a>
</div>

</body>
</html>
