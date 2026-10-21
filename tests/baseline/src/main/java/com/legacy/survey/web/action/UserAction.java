package com.legacy.survey.web.action;

import java.net.URLEncoder;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.ibatis.session.SqlSession;
import org.apache.struts.action.ActionForm;
import org.apache.struts.action.ActionForward;
import org.apache.struts.action.ActionMapping;
import org.apache.struts.actions.DispatchAction;

import com.legacy.survey.pojo.User;
import com.legacy.survey.dao.MyBatisUtil;
import com.legacy.survey.dao.UserMapper;
import com.legacy.survey.util.MD5Util;
import com.legacy.survey.web.LoginCheckFilter;

/**
 * 用户管理 (增删改查)
 *
 * @author crm-dev
 * @since 2016-11-10
 */
public class UserAction extends DispatchAction {

    /** 用户列表 */
    public ActionForward list(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        SqlSession session = MyBatisUtil.openSession();
        try {
            request.setAttribute("users", session.getMapper(UserMapper.class).selectAll());
        } finally {
            session.close();
        }
        // 带回来的提示信息 (删除被拒等)
        String msg = request.getParameter("msg");
        if (msg != null && msg.trim().length() > 0) {
            request.setAttribute("msg", msg);
        }
        return new ActionForward("/user_list.jsp");
    }

    /** 打开新增/编辑页 */
    public ActionForward edit(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        long id = parseLong(request.getParameter("id"), 0);
        if (id > 0) {
            SqlSession session = MyBatisUtil.openSession();
            try {
                request.setAttribute("user", session.getMapper(UserMapper.class).selectById(id));
            } finally {
                session.close();
            }
        }
        return new ActionForward("/user_edit.jsp");
    }

    /** 保存 (新增或修改) */
    public ActionForward save(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        long id = parseLong(request.getParameter("id"), 0);
        String username = trim(request.getParameter("username"));
        String realName = trim(request.getParameter("realName"));
        String password = trim(request.getParameter("password"));
        int role = parseInt(request.getParameter("role"), User.ROLE_ADMIN);
        int status = parseInt(request.getParameter("status"), 1);

        // 超级管理员只能由 DBA 脚本初始化, 页面创建一律拒绝
        if (role == User.ROLE_SUPER_ADMIN) {
            request.setAttribute("errorMsg", "超级管理员不能在页面创建, 只能由 DBA 脚本初始化");
            return new ActionForward("/user_edit.jsp");
        }

        SqlSession session = MyBatisUtil.openSession();
        try {
            UserMapper mapper = session.getMapper(UserMapper.class);

            if (id > 0) {
                // 修改
                User user = new User();
                user.setId(id);
                user.setRealName(realName);
                user.setRole(role);
                user.setStatus(status);
                if (password.length() > 0) {
                    user.setPassword(MD5Util.md5(password));
                }
                mapper.update(user);
            } else {
                // 新增
                if (username.length() == 0) {
                    request.setAttribute("errorMsg", "用户名不能为空");
                    session.close();
                    return new ActionForward("/user_edit.jsp");
                }
                if (password.length() == 0) {
                    request.setAttribute("errorMsg", "密码不能为空");
                    session.close();
                    return new ActionForward("/user_edit.jsp");
                }
                if (mapper.selectByUsername(username) != null) {
                    request.setAttribute("errorMsg", "用户名已存在");
                    session.close();
                    return new ActionForward("/user_edit.jsp");
                }
                User user = new User();
                user.setUsername(username);
                user.setPassword(MD5Util.md5(password));
                user.setRealName(realName);
                user.setRole(role);
                user.setStatus(status);
                mapper.insert(user);
            }
            session.commit();
        } finally {
            session.close();
        }
        return new ActionForward("/user.do?method=list", true);
    }

    /** 删除 (逻辑删; 超级管理员和当前登录账号不允许删) */
    public ActionForward delete(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        long id = parseLong(request.getParameter("id"), 0);
        String msg = null;

        SqlSession session = MyBatisUtil.openSession();
        try {
            UserMapper mapper = session.getMapper(UserMapper.class);
            User user = mapper.selectById(id);
            if (user == null) {
                msg = "用户不存在";
            } else if (user.getRole() == User.ROLE_SUPER_ADMIN || "admin".equals(user.getUsername())) {
                msg = "超级管理员不允许删除";
            } else {
                User loginUser = (User) request.getSession().getAttribute(LoginCheckFilter.SESSION_USER_KEY);
                if (loginUser != null && loginUser.getId() == user.getId()) {
                    msg = "不能删除当前登录账号";
                } else {
                    mapper.logicalDelete(id);
                    session.commit();
                }
            }
        } finally {
            session.close();
        }

        String target = "/user.do?method=list";
        if (msg != null) {
            target = target + "&msg=" + URLEncoder.encode(msg, "UTF-8");
        }
        return new ActionForward(target, true);
    }

    private static String trim(String s) {
        return s == null ? "" : s.trim();
    }

    private static long parseLong(String s, long def) {
        try {
            return Long.parseLong(trim(s));
        } catch (NumberFormatException e) {
            return def;
        }
    }

    private static int parseInt(String s, int def) {
        try {
            return Integer.parseInt(trim(s));
        } catch (NumberFormatException e) {
            return def;
        }
    }
}
