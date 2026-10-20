<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>问卷配置 - CRM 问卷系统</title>
    <style type="text/css">
        body { font-family: SimSun, serif; font-size: 12px; margin: 20px; }
        h3 { border-bottom: 1px solid #cccccc; padding-bottom: 4px; }
        table.form td { padding: 4px 6px; }
    </style>
</head>
<body>

<h3>问卷配置</h3>

<div style="color: green;">
<%= request.getParameter("saved") != null ? "保存成功!" : "" %>
</div>

<form id="surveyForm" action="${pageContext.request.contextPath}/surveyConfig.do" method="post">
    <input type="hidden" name="csrfToken" value="${sessionScope.CSRF_TOKEN}"/>
    <input type="hidden" name="id" value="0"/>

    <table class="form">
        <tr>
            <td>问卷名称:</td>
            <td><input type="text" name="surveyName" size="50" maxlength="200"/></td>
        </tr>
        <tr>
            <td>题目1 (选择式):</td>
            <td>
                <input type="hidden" name="questions[0].id" value="0"/>
                <input type="hidden" name="questions[0].type" value="1"/>
                <input type="hidden" name="questions[0].sort" value="1"/>
                <input type="text" name="questions[0].text" size="60" maxlength="1000"/>
            </td>
        </tr>
        <tr>
            <td>选项:</td>
            <td>
                <input type="text" name="questions[0].answers[0].content" size="25"/>
                <input type="text" name="questions[0].answers[1].content" size="25"/>
                <input type="text" name="questions[0].answers[2].content" size="25"/>
            </td>
        </tr>
        <tr>
            <td>题目2 (开放式):</td>
            <td>
                <input type="hidden" name="questions[1].id" value="0"/>
                <input type="hidden" name="questions[1].type" value="2"/>
                <input type="hidden" name="questions[1].sort" value="2"/>
                <input type="text" name="questions[1].text" size="60" maxlength="1000"/>
            </td>
        </tr>
        <tr>
            <td colspan="2" align="center">
                <input type="submit" value=" 保 存 "/>
            </td>
        </tr>
    </table>
</form>

</body>
</html>
