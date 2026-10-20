<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>题目编辑 - CRM 问卷系统</title>
    <style type="text/css">
        body { font-family: SimSun, serif; font-size: 12px; margin: 20px; }
        h3 { border-bottom: 1px solid #cccccc; padding-bottom: 4px; }
        td { padding: 4px 6px; }
        .err { color: red; }
    </style>
    <script type="text/javascript">
        // 选择式才有选项
        function toggleOptions() {
            var choice = document.getElementById("typeChoice").checked;
            document.getElementById("optionArea").style.display = choice ? "" : "none";
        }
        window.onload = toggleOptions;
    </script>
</head>
<body>

<h3>${empty question ? '新增题目' : '编辑题目'}</h3>
<div class="err">${errorMsg}</div>

<form action="${pageContext.request.contextPath}/question.do?method=save" method="post">
    <input type="hidden" name="csrfToken" value="${sessionScope.CSRF_TOKEN}"/>
    <input type="hidden" name="id" value="${empty question ? 0 : question.id}"/>

    <table>
        <tr>
            <td>题型:</td>
            <td>
                <input type="radio" name="questionType" id="typeChoice" value="1"
                       onclick="toggleOptions()" ${question.type == 1 or empty question ? 'checked' : ''}/> 选择式
                <input type="radio" name="questionType" id="typeOpen" value="2"
                       onclick="toggleOptions()" ${question.type == 2 ? 'checked' : ''}/> 开放式
            </td>
        </tr>
        <tr>
            <td>题干:</td>
            <td><textarea name="content" rows="3" cols="60">${question.text}</textarea></td>
        </tr>
        <tr>
            <td>排序号:</td>
            <td><input type="text" name="sortNo" value="${empty question ? 0 : question.sort}" size="6"/></td>
        </tr>
        <tr>
            <td>选项:</td>
            <td>
                <div id="optionArea">
                    <c:forEach var="opt" items="${options}">
                        <div><input type="text" name="optionContent" value="${opt.content}" size="30"/></div>
                    </c:forEach>
                    <div><input type="text" name="optionContent" size="30"/></div>
                    <div><input type="text" name="optionContent" size="30"/></div>
                    <div>(开放式题目不用填选项)</div>
                </div>
            </td>
        </tr>
        <tr>
            <td colspan="2" align="center"><input type="submit" value=" 保 存 "/></td>
        </tr>
    </table>
</form>

<div style="margin-top: 12px;">
    <a href="${pageContext.request.contextPath}/question.do?method=list">返回题库</a>
</div>

</body>
</html>
