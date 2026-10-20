<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>${survey.title} - 调查进行中</title>
    <style type="text/css">
        body { font-family: SimSun, serif; font-size: 12px; margin: 20px; }
        h3 { border-bottom: 1px solid #cccccc; padding-bottom: 4px; }
        .question { margin: 12px 0; }
        .option { margin: 4px 0; }
    </style>
</head>
<body>

<h3>${survey.title} <span style="font-size: 12px; font-weight: normal;">(调查进行中)</span></h3>
<div>${survey.description}</div>

<form>
    <c:forEach var="q" items="${questions}" varStatus="st">
    <div class="question">
        <b>${st.index + 1}. ${q.text}</b>
        <c:if test="${q.isRequired == 1}"><span style="color: red;">*</span></c:if>
        <c:choose>
            <c:when test="${q.type == 1}">
                <c:forEach var="opt" items="${q.answers}">
                    <div class="option">
                        <label><input type="radio" name="q_${q.id}" value="${opt.id}"/> ${opt.content}</label>
                    </div>
                </c:forEach>
            </c:when>
            <c:otherwise>
                <div class="option">
                    <textarea name="q_${q.id}" rows="3" cols="60"></textarea>
                </div>
            </c:otherwise>
        </c:choose>
    </div>
    </c:forEach>
    <div>
        <input type="submit" value=" 提交问卷 "/>
    </div>
</form>

<div style="margin-top: 12px;">
    <a href="${pageContext.request.contextPath}/survey.do?method=questions&surveyId=${survey.id}">返回题目设置</a>
</div>

</body>
</html>
