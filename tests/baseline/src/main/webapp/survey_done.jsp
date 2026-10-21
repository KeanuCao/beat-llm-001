<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>CRM 问卷系统</title>
    <style type="text/css">
        body { font-family: SimSun, serif; font-size: 12px; margin: 20px; }
        .box { width: 420px; border: 1px solid #cccccc; padding: 20px; margin: 60px auto; text-align: center; }
    </style>
</head>
<body>

<div class="box">
    <c:choose>
        <c:when test="${already}">
            <h3>温馨提示</h3>
            <p>您已经回答问卷, 感谢您的参与!</p>
        </c:when>
        <c:otherwise>
            <h3>问卷已提交</h3>
            <p>感谢您的参与! (${email})</p>
        </c:otherwise>
    </c:choose>
</div>

</body>
</html>
