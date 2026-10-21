<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>用户编辑 - CRM 问卷系统</title>
    <style type="text/css">
        body { font-family: SimSun, serif; font-size: 12px; margin: 20px; }
        h3 { border-bottom: 1px solid #cccccc; padding-bottom: 4px; }
        td { padding: 4px 6px; }
        .err { color: red; }
    </style>
</head>
<body>

<h3>${empty user ? '新增用户' : '编辑用户'}</h3>
<div class="err">${errorMsg}</div>

<form action="${pageContext.request.contextPath}/user.do?method=save" method="post">
    <input type="hidden" name="csrfToken" value="${sessionScope.CSRF_TOKEN}"/>
    <input type="hidden" name="id" value="${empty user ? 0 : user.id}"/>

    <table>
        <tr>
            <td>用户名:</td>
            <td>
                <c:choose>
                    <c:when test="${not empty user}">
                        <input type="text" value="${user.username}" readonly/>
                    </c:when>
                    <c:otherwise>
                        <input type="text" name="username" size="20"/>
                    </c:otherwise>
                </c:choose>
            </td>
        </tr>
        <tr>
            <td>密码:</td>
            <td>
                <input type="password" name="password" size="22"/>
                ${not empty user ? '(留空表示不修改)' : ''}
            </td>
        </tr>
        <tr>
            <td>姓名:</td>
            <td><input type="text" name="realName" value="${user.realName}" size="20"/></td>
        </tr>
        <tr>
            <td>角色:</td>
            <td>
                <select name="role">
                    <option value="1" ${user.role == 1 ? 'selected' : ''}>普通管理员</option>
                    <%-- 超级管理员不提供选项, 只能 DBA 脚本初始化 --%>
                </select>
            </td>
        </tr>
        <tr>
            <td>状态:</td>
            <td>
                <select name="status">
                    <option value="1" ${empty user or user.status == 1 ? 'selected' : ''}>启用</option>
                    <option value="0" ${not empty user and user.status == 0 ? 'selected' : ''}>停用</option>
                </select>
            </td>
        </tr>
        <tr>
            <td colspan="2" align="center"><input type="submit" value=" 保 存 "/></td>
        </tr>
    </table>
</form>

<div style="margin-top: 12px;">
    <a href="${pageContext.request.contextPath}/user.do?method=list">返回列表</a>
</div>

</body>
</html>
