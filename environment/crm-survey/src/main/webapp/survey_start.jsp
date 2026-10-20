<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>开始调查 - CRM 问卷系统</title>
    <style type="text/css">
        body { font-family: SimSun, serif; font-size: 12px; margin: 20px; }
        h3 { border-bottom: 1px solid #cccccc; padding-bottom: 4px; }
        td { padding: 4px 6px; }
        .err { color: red; }
    </style>
</head>
<body>

<h3>开始调查 - ${survey.title}</h3>
<div class="err">${errorMsg}</div>

<form action="${pageContext.request.contextPath}/survey.do?method=launch" method="post">
    <input type="hidden" name="csrfToken" value="${sessionScope.CSRF_TOKEN}"/>
    <input type="hidden" name="surveyId" value="${survey.id}"/>

    <table>
        <tr>
            <td>开始日期:</td>
            <td><input type="text" name="startDate" size="12"/> (yyyy-MM-dd)</td>
        </tr>
        <tr>
            <td>结束日期:</td>
            <td><input type="text" name="endDate" size="12"/> (yyyy-MM-dd)</td>
        </tr>
        <tr>
            <td>受访者邮件列表:</td>
            <td>
                <textarea name="emails" rows="8" cols="50"></textarea>
                (每行一个邮箱, 也支持逗号分隔)
            </td>
        </tr>
        <tr>
            <td colspan="2" align="center"><input type="submit" value=" 开始调查 "/></td>
        </tr>
    </table>
</form>

<div style="margin-top: 12px;">
    <a href="${pageContext.request.contextPath}/survey.do?method=questions&surveyId=${survey.id}">返回题目设置</a>
</div>

</body>
</html>
