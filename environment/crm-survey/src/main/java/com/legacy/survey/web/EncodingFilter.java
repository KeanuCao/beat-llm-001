package com.legacy.survey.web;

import java.io.IOException;

import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;

/**
 * 全站编码过滤器, 不加这个中文参数全成乱码 (2006 年起每个项目第一个 filter 就是它)
 *
 * @author crm-dev
 * @since 2006-04-01
 */
public class EncodingFilter implements Filter {

    public void init(FilterConfig filterConfig) throws ServletException {
    }

    public void destroy() {
    }

    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        request.setCharacterEncoding("UTF-8");
        chain.doFilter(request, response);
    }
}
