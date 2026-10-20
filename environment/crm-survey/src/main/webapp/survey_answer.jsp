<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>${survey.title} - 问卷作答</title>
    <style type="text/css">
        body { font-family: SimSun, serif; font-size: 12px; margin: 20px; }
        h3 { border-bottom: 1px solid #cccccc; padding-bottom: 4px; }
        .question { margin: 12px 0; }
        .option { margin: 4px 0; }
    </style>
    <script type="text/javascript">
        // 单选题: 每个选项是独立 radio (名字带下标), 靠 JS 保证同题只选一个
        function singlePick(input) {
            var box = input.parentNode;
            while (box && box.className != "question") {
                box = box.parentNode;
            }
            if (!box) {
                return;
            }
            var inputs = box.getElementsByTagName("input");
            for (var i = 0; i < inputs.length; i++) {
                if (inputs[i] != input && inputs[i].type == "radio") {
                    inputs[i].checked = false;
                }
            }
        }
    </script>
</head>
<body>

<h3>${survey.title} <span style="font-size: 12px; font-weight: normal;">(问卷作答)</span></h3>
<div>${survey.description}</div>

<%-- 嵌套参数: questions[序号].xxx / answers[序号].xxx --%>
<form action="${pageContext.request.contextPath}/surveyAnswer.do" method="post">
    <input type="hidden" name="csrfToken" value="${sessionScope.CSRF_TOKEN}"/>
    <input type="hidden" name="t" value="${invite.uuid}"/>
    <input type="hidden" name="inviteUuid" value="${invite.uuid}"/>

    <div class="question">
        <b>您的邮件地址</b> <span style="color: red;">*</span> (用于核对您的邀请身份)
        <div class="option">
            <input type="text" name="email" size="30"/>
        </div>
    </div>

    <c:forEach var="q" items="${questions}" varStatus="st">
    <div class="question">
        <input type="hidden" name="questions[${st.index}].id" value="${q.id}"/>
        <input type="hidden" name="questions[${st.index}].type" value="${q.type}"/>
        <input type="hidden" name="questions[${st.index}].text" value="${q.text}"/>

        <b>${st.index + 1}. ${q.text}</b>
        <c:if test="${q.isRequired == 1}"><span style="color: red;">*</span></c:if>
        <c:choose>
            <c:when test="${q.type == 1}">
                <c:forEach var="opt" items="${optionsByQuestionId[q.id]}" varStatus="oj">
                    <div class="option">
                        <input type="hidden" name="questions[${st.index}].answers[${oj.index}].content" value="${opt.content}"/>
                        <label><input type="radio" name="questions[${st.index}].answers[${oj.index}].id" value="${opt.id}" onclick="singlePick(this)"/> ${opt.content}</label>
                    </div>
                </c:forEach>
            </c:when>
            <c:when test="${q.type == 2}">
                <c:forEach var="opt" items="${optionsByQuestionId[q.id]}" varStatus="oj">
                    <div class="option">
                        <input type="hidden" name="questions[${st.index}].answers[${oj.index}].content" value="${opt.content}"/>
                        <label><input type="checkbox" name="questions[${st.index}].answers[${oj.index}].id" value="${opt.id}"/> ${opt.content}</label>
                    </div>
                </c:forEach>
            </c:when>
            <c:otherwise>
                <div class="option">
                    <input type="hidden" name="questions[${st.index}].answers[0].id" value="0"/>
                    <textarea name="questions[${st.index}].answers[0].content" rows="3" cols="60"></textarea>
                </div>
            </c:otherwise>
        </c:choose>
    </div>
    </c:forEach>

    <div>
        <input type="submit" value=" 提交问卷 "/>
    </div>
</form>

</body>
</html>
