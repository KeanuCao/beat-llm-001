<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>回答详情 - CRM 问卷系统</title>
    <style type="text/css">
        body { font-family: SimSun, serif; font-size: 12px; margin: 20px; }
        h3 { border-bottom: 1px solid #cccccc; padding-bottom: 4px; }
        table { border-collapse: collapse; }
        td { padding: 4px 8px; }
        .card { border: 1px solid #dde6f0; margin: 12px 0; padding: 10px; }
        .who { background: #e8eef7; padding: 6px 8px; }
        .empty { color: #888888; }
    </style>
</head>
<body>

<h3>
    回答详情 - ${survey.title}
    <a style="float: right; font-size: 12px; font-weight: normal;" href="${pageContext.request.contextPath}/survey.do?method=list">返回列表</a>
</h3>

<c:if test="${empty feedbacks}">
    <div class="empty">还没有人回答这份问卷</div>
</c:if>

<c:forEach var="fb" items="${feedbacks}">
<div class="card">
    <div class="who">
        <b>${fb.email}</b>&nbsp;&nbsp;
        <fmt:formatDate value="${fb.createTime}" pattern="yyyy-MM-dd HH:mm"/>
    </div>
    <c:choose>
        <c:when test="${empty fb.questions}">
            <div class="empty" style="padding: 6px;">(回答内容缺失)</div>
        </c:when>
        <c:otherwise>
            <table>
                <c:forEach var="fq" items="${fb.questions}">
                <tr>
                    <td style="width: 45%;">
                        ${fq.questionContent}
                        <span style="color: #888888;">
                            <c:choose>
                                <c:when test="${fq.questionType == 1}">[单选]</c:when>
                                <c:when test="${fq.questionType == 2}">[多选]</c:when>
                                <c:otherwise>[开放式]</c:otherwise>
                            </c:choose>
                        </span>
                    </td>
                    <td>
                        <c:choose>
                            <c:when test="${fq.questionType == 3}">
                                ${fq.answerContent}
                            </c:when>
                            <c:otherwise>
                                <c:forEach var="fo" items="${fq.options}" varStatus="st">${st.index > 0 ? '、' : ''}${fo.optionContent}</c:forEach>
                            </c:otherwise>
                        </c:choose>
                    </td>
                </tr>
                </c:forEach>
            </table>
        </c:otherwise>
    </c:choose>
</div>
</c:forEach>

</body>
</html>
