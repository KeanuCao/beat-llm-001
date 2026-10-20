package com.legacy.survey.web.action;

import java.net.URLEncoder;
import java.util.List;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.ibatis.session.SqlSession;
import org.apache.struts.action.ActionForm;
import org.apache.struts.action.ActionForward;
import org.apache.struts.action.ActionMapping;
import org.apache.struts.actions.DispatchAction;

import com.legacy.survey.Answer;
import com.legacy.survey.Question;
import com.legacy.survey.dao.MyBatisUtil;
import com.legacy.survey.dao.StandardQuestionMapper;

/**
 * 标准题库管理 (题目三种类型: 1-单选 2-多选 3-开放式)
 *
 * @author crm-dev
 * @since 2016-11-11
 */
public class StandardQuestionAction extends DispatchAction {

    /** 题型: 单选 (带选项, 只选一个) */
    public static final int TYPE_SINGLE = 1;

    /** 题型: 多选 (带选项, 可选多个) */
    public static final int TYPE_MULTI = 2;

    /** 题型: 开放式 (自由作答, 无选项) */
    public static final int TYPE_OPEN = 3;

    /** 题库列表 */
    public ActionForward list(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        SqlSession session = MyBatisUtil.openSession();
        try {
            request.setAttribute("questions", session.getMapper(StandardQuestionMapper.class).selectAll());
        } finally {
            session.close();
        }
        String msg = request.getParameter("msg");
        if (msg != null && msg.trim().length() > 0) {
            request.setAttribute("msg", msg);
        }
        return new ActionForward("/question_list.jsp");
    }

    /** 打开新增/编辑页 */
    public ActionForward edit(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        long id = parseLong(request.getParameter("id"), 0);
        if (id > 0) {
            SqlSession session = MyBatisUtil.openSession();
            try {
                StandardQuestionMapper mapper = session.getMapper(StandardQuestionMapper.class);
                request.setAttribute("question", mapper.selectById(id));
                request.setAttribute("options", mapper.selectOptionsByQuestionId(id));
            } finally {
                session.close();
            }
        }
        return new ActionForward("/question_edit.jsp");
    }

    /** 保存 (新增或修改; 选项先删后插) */
    public ActionForward save(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        long id = parseLong(request.getParameter("id"), 0);
        int type = parseInt(request.getParameter("questionType"), TYPE_SINGLE);
        String content = trim(request.getParameter("content"));
        String sortParam = request.getParameter("sortNo");
        int sort = parseInt(sortParam, 0);
        String[] optionContents = request.getParameterValues("optionContent");

        if (content.length() == 0) {
            request.setAttribute("errorMsg", "题干不能为空");
            return new ActionForward("/question_edit.jsp");
        }
        if (type != TYPE_SINGLE && type != TYPE_MULTI && type != TYPE_OPEN) {
            request.setAttribute("errorMsg", "题型不合法");
            return new ActionForward("/question_edit.jsp");
        }

        SqlSession session = MyBatisUtil.openSession();
        try {
            StandardQuestionMapper mapper = session.getMapper(StandardQuestionMapper.class);

            Question question = new Question();
            question.setType(type);
            question.setText(content);

            if (id > 0) {
                question.setId(id);
                // 页面已不再提供排序号, 未传时沿用原值
                if (sortParam == null) {
                    Question existing = mapper.selectById(id);
                    question.setSort(existing == null ? 0 : existing.getSort());
                } else {
                    question.setSort(sort);
                }
                mapper.update(question);
                // 选项改法: 先物理删干净再插 (老代码一贯做法)
                mapper.deleteOptionsByQuestionId(id);
            } else {
                question.setSort(sort);
                mapper.insert(question);
            }

            // 单选/多选存选项
            if (type != TYPE_OPEN && optionContents != null) {
                int sortNo = 1;
                for (String optionContent : optionContents) {
                    String content2 = optionContent == null ? "" : optionContent.trim();
                    if (content2.length() == 0) {
                        continue;
                    }
                    mapper.insertOption(question.getId(), content2, sortNo++);
                }
            }
            session.commit();
        } finally {
            session.close();
        }
        return new ActionForward("/question.do?method=list", true);
    }

    /** 删除题目 (逻辑删题目, 物理删选项) */
    public ActionForward delete(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        long id = parseLong(request.getParameter("id"), 0);
        String msg = null;

        SqlSession session = MyBatisUtil.openSession();
        try {
            StandardQuestionMapper mapper = session.getMapper(StandardQuestionMapper.class);
            Question question = mapper.selectById(id);
            if (question == null) {
                msg = "题目不存在";
            } else {
                mapper.logicalDelete(id);
                mapper.deleteOptionsByQuestionId(id);
                session.commit();
            }
        } finally {
            session.close();
        }

        String target = "/question.do?method=list";
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
