<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>菜单</title>
    <style type="text/css">
        body { font-family: SimSun, serif; font-size: 12px; margin: 0; background: #e8eef7; }
        .logo { padding: 12px; font-weight: bold; border-bottom: 1px solid #cccccc; background: #3a6ea5; color: #ffffff; }
        a { display: block; padding: 8px 12px; color: #333333; text-decoration: none; border-bottom: 1px solid #dde6f0; }
        a:hover { background: #d0e0f0; }
    </style>
</head>
<body>

<div class="logo">CRM 问卷系统</div>
<a href="${pageContext.request.contextPath}/user.do?method=list" target="main">用户管理</a>
<a href="${pageContext.request.contextPath}/question.do?method=list" target="main">题目管理</a>
<a href="${pageContext.request.contextPath}/survey.do?method=list" target="main">问卷管理</a>

</body>
</html>
