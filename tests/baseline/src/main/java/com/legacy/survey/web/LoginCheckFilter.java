package com.legacy.survey.web;

import java.io.IOException;

import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;

/**
 * 后台页面登录检查, 没登录一律踢回 login.jsp
 *
 * @author crm-dev
 * @since 2016-11-10
 */
public class LoginCheckFilter implements Filter {

    /** 登录用户在 session 里的 key */
    public static final String SESSION_USER_KEY = "loginUser";

    public void init(FilterConfig filterConfig) throws ServletException {
    }

    public void destroy() {
    }

    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest req = (HttpServletRequest) request;
        HttpServletResponse resp = (HttpServletResponse) response;

        HttpSession session = req.getSession(false);
        if (session == null || session.getAttribute(SESSION_USER_KEY) == null) {
            resp.sendRedirect(req.getContextPath() + "/login.jsp");
            return;
        }
        chain.doFilter(request, response);
    }
}
