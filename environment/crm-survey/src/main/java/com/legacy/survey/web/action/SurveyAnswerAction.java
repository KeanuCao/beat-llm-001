package com.legacy.survey.web.action;

import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.ibatis.session.SqlSession;
import org.apache.struts.action.Action;
import org.apache.struts.action.ActionForm;
import org.apache.struts.action.ActionForward;
import org.apache.struts.action.ActionMapping;

import com.legacy.survey.Answer;
import com.legacy.survey.Question;
import com.legacy.survey.SurveyInvite;
import com.legacy.survey.dao.MyBatisUtil;
import com.legacy.survey.dao.SurveyAnswerMapper;
import com.legacy.survey.dao.SurveyInviteMapper;
import com.legacy.survey.dao.SurveyQuestionMapper;
import com.legacy.survey.util.MaskUtil;

/**
 * 受访者作答: 邮件链接进来 (uuid), 作答时必须填邮箱, 后端校验掩码匹配
 *
 * @author crm-dev
 * @since 2016-11-13
 */
public class SurveyAnswerAction extends Action {

    /** 受访者页面统一错误出口 */
    private ActionForward globalError(HttpServletRequest request, String msg) {
        request.setAttribute("errorMsg", msg);
        return new ActionForward("/global_error.jsp");
    }

    @Override
    public ActionForward execute(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        if ("POST".equalsIgnoreCase(request.getMethod())) {
            return submit(request);
        }
        return open(request);
    }

    /** 打开作答页 (邮件链接) */
    private ActionForward open(HttpServletRequest request) {
        String token = trim(request.getParameter("t"));
        if (token.length() == 0) {
            return globalError(request, "链接无效");
        }

        SqlSession session = MyBatisUtil.openSession();
        try {
            SurveyInviteMapper inviteMapper = session.getMapper(SurveyInviteMapper.class);
            SurveyInvite invite = inviteMapper.selectByUuid(token);
            if (invite == null) {
                return globalError(request, "链接无效或已过期");
            }
            if (invite.getStatus() == SurveyInvite.STATUS_ANSWERED) {
                return globalError(request, "该邀请已经作答过, 谢谢参与");
            }

            SurveyQuestionMapper questionMapper = session.getMapper(SurveyQuestionMapper.class);
            List<Question> questions = questionMapper.selectBySurveyId(invite.getSurveyId());
            for (Question q : questions) {
                q.setAnswers(questionMapper.selectOptionsByQuestionId(q.getId()));
            }
            request.setAttribute("invite", invite);
            request.setAttribute("questions", questions);
        } finally {
            session.close();
        }
        return new ActionForward("/survey_answer.jsp");
    }

    /** 提交作答: 邮箱 + 掩码必须匹配, 不匹配直接 global error */
    private ActionForward submit(HttpServletRequest request) {
        String token = trim(request.getParameter("t"));
        String email = trim(request.getParameter("email"));
        if (token.length() == 0) {
            return globalError(request, "链接无效");
        }
        if (email.length() == 0 || email.indexOf('@') < 0) {
            return globalError(request, "请输入有效的邮件地址");
        }

        SqlSession session = MyBatisUtil.openSession();
        try {
            SurveyInviteMapper inviteMapper = session.getMapper(SurveyInviteMapper.class);
            SurveyInvite invite = inviteMapper.selectByUuid(token);
            if (invite == null) {
                return globalError(request, "链接无效或已过期");
            }
            if (invite.getStatus() == SurveyInvite.STATUS_ANSWERED) {
                return globalError(request, "该邀请已经作答过, 谢谢参与");
            }

            // 关卡: 输入的邮箱算出来的掩码必须和邀请里存的一致
            if (!MaskUtil.mask(email).equals(invite.getEmailMask())) {
                return globalError(request, "邮件地址与本次邀请不匹配");
            }

            // 逐题落库: 选择式记选项ID, 开放式记文本
            SurveyQuestionMapper questionMapper = session.getMapper(SurveyQuestionMapper.class);
            List<Question> questions = questionMapper.selectBySurveyId(invite.getSurveyId());
            Map<Long, Question> questionMap = new HashMap<Long, Question>();
            for (Question q : questions) {
                questionMap.put(Long.valueOf(q.getId()), q);
            }

            SurveyAnswerMapper answerMapper = session.getMapper(SurveyAnswerMapper.class);
            Map<String, String[]> params = request.getParameterMap();
            Iterator<String> keys = params.keySet().iterator();
            while (keys.hasNext()) {
                String key = keys.next();
                if (!key.startsWith("q_")) {
                    continue;
                }
                long questionId = parseLong(key.substring(2), 0);
                Question question = questionMap.get(Long.valueOf(questionId));
                if (question == null) {
                    continue;
                }
                String[] values = params.get(key);
                String value = values == null || values.length == 0 ? "" : values[0].trim();
                if (value.length() == 0) {
                    continue;
                }
                if (question.getType() == 1) {
                    // 选择式: 值是选项ID
                    long optionId = parseLong(value, 0);
                    String optionContent = null;
                    for (Answer option : question.getAnswers()) {
                        if (option.getId() == optionId) {
                            optionContent = option.getContent();
                            break;
                        }
                    }
                    if (optionId <= 0) {
                        continue;
                    }
                    answerMapper.insert(invite.getUuid(), invite.getSurveyId(), questionId, optionId, optionContent, email);
                } else {
                    // 开放式: 值是作答文本
                    answerMapper.insert(invite.getUuid(), invite.getSurveyId(), questionId, 0, value, email);
                }
            }

            inviteMapper.markAnswered(invite.getId());
            session.commit();
            request.setAttribute("email", email);
        } finally {
            session.close();
        }
        return new ActionForward("/survey_done.jsp");
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
}
