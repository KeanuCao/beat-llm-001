package com.legacy.survey.web.action;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.ibatis.session.SqlSession;
import org.apache.struts.action.Action;
import org.apache.struts.action.ActionForm;
import org.apache.struts.action.ActionForward;
import org.apache.struts.action.ActionMapping;

import com.legacy.survey.User;
import com.legacy.survey.dao.MyBatisUtil;
import com.legacy.survey.dao.UserMapper;
import com.legacy.survey.util.MD5Util;
import com.legacy.survey.web.LoginCheckFilter;

/**
 * 登录
 *
 * @author crm-dev
 * @since 2016-11-10
 */
public class LoginAction extends Action {

    @Override
    public ActionForward execute(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        if (!"POST".equalsIgnoreCase(request.getMethod())) {
            return new ActionForward("/login.jsp");
        }

        String username = request.getParameter("username");
        String password = request.getParameter("password");

        User user = null;
        SqlSession session = MyBatisUtil.openSession();
        try {
            UserMapper mapper = session.getMapper(UserMapper.class);
            user = mapper.selectByUsername(username == null ? "" : username.trim());
        } finally {
            session.close();
        }

        if (user == null || user.getStatus() != 1
                || !MD5Util.md5(password == null ? "" : password).equals(user.getPassword())) {
            request.setAttribute("errorMsg", "用户名或密码错误");
            return new ActionForward("/login.jsp");
        }

        // 登录成功, 进后台主框架
        request.getSession(true).setAttribute(LoginCheckFilter.SESSION_USER_KEY, user);
        return new ActionForward("/index.jsp", true);
    }
}
