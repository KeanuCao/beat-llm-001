<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>登录 - CRM 问卷系统</title>
    <style type="text/css">
        body { font-family: SimSun, serif; font-size: 12px; margin: 20px; }
        .box { width: 340px; border: 1px solid #cccccc; padding: 20px; margin: 80px auto; }
        .err { color: red; }
        td { padding: 4px; }
    </style>
</head>
<body>

<div class="box">
    <h3>CRM 问卷系统 - 登录</h3>
    <div class="err">${errorMsg}</div>
    <form action="${pageContext.request.contextPath}/login.do" method="post">
        <input type="hidden" name="csrfToken" value="${sessionScope.CSRF_TOKEN}"/>
        <table>
            <tr>
                <td>用户名:</td>
                <td><input type="text" name="username" size="20"/></td>
            </tr>
            <tr>
                <td>密码:</td>
                <td><input type="password" name="password" size="22"/></td>
            </tr>
            <tr>
                <td colspan="2" align="center"><input type="submit" value=" 登 录 "/></td>
            </tr>
        </table>
    </form>
</div>

</body>
</html>
