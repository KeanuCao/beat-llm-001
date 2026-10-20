<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>出错了 - CRM 问卷系统</title>
    <style type="text/css">
        body { font-family: SimSun, serif; font-size: 12px; margin: 20px; }
        .box { width: 420px; border: 1px solid #cccccc; padding: 20px; margin: 60px auto; text-align: center; }
        .err { color: red; }
    </style>
</head>
<body>

<div class="box">
    <h3>系统提示</h3>
    <p class="err">${empty errorMsg ? '系统繁忙, 请稍后再试' : errorMsg}</p>
    <p><a href="${pageContext.request.contextPath}/login.jsp">返回首页</a></p>
</div>

</body>
</html>
