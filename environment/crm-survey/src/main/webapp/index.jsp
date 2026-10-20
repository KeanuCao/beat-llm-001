<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>CRM 问卷系统</title>
</head>
<frameset cols="180,*">
    <frame src="menu.jsp" name="menu"/>
    <frame src="${pageContext.request.contextPath}/survey.do?method=list" name="main"/>
</frameset>
</html>
