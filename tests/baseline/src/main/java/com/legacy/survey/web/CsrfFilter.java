package com.legacy.survey.web;

import java.io.IOException;
import java.util.UUID;

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
 * CSRF 防护过滤器, 所有请求都过一遍
 * GET 时保证 session 里有 token (页面取用), POST 时校验, 不过就 403
 *
 * @author crm-dev
 * @since 2014-06-11
 */
public class CsrfFilter implements Filter {

    /** session 里的 token key */
    public static final String SESSION_TOKEN_KEY = "CSRF_TOKEN";

    /** 表单里的参数名 */
    public static final String TOKEN_PARAM = "csrfToken";

    public void init(FilterConfig filterConfig) throws ServletException {
    }

    public void destroy() {
    }

    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest req = (HttpServletRequest) request;
        HttpServletResponse resp = (HttpServletResponse) response;
        HttpSession session = req.getSession(true);

        String method = req.getMethod();
        if ("GET".equalsIgnoreCase(method)) {
            // GET: 没有就发一个, 页面表单里要用
            if (session.getAttribute(SESSION_TOKEN_KEY) == null) {
                session.setAttribute(SESSION_TOKEN_KEY, newToken());
            }
            chain.doFilter(request, response);
        } else if ("POST".equalsIgnoreCase(method)) {
            String sessionToken = (String) session.getAttribute(SESSION_TOKEN_KEY);
            String paramToken = req.getParameter(TOKEN_PARAM);
            if (sessionToken == null || paramToken == null || !sessionToken.equals(paramToken)) {
                resp.sendError(HttpServletResponse.SC_FORBIDDEN, "CSRF token check failed");
                return;
            }
            chain.doFilter(request, response);
        } else {
            chain.doFilter(request, response);
        }
    }

    private String newToken() {
        return UUID.randomUUID().toString().replace("-", "");
    }
}
