package com.legacy.survey.web.action;

import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.ibatis.session.SqlSession;
import org.apache.struts.action.Action;
import org.apache.struts.action.ActionForm;
import org.apache.struts.action.ActionForward;
import org.apache.struts.action.ActionMapping;

import com.legacy.survey.Answer;
import com.legacy.survey.Question;
import com.legacy.survey.SurveyFeedback;
import com.legacy.survey.SurveyFeedbackOption;
import com.legacy.survey.SurveyFeedbackQuestion;
import com.legacy.survey.SurveyInvite;
import com.legacy.survey.dao.MyBatisUtil;
import com.legacy.survey.dao.SurveyFeedbackMapper;
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

    private static final Log logger = LogFactory.getLog(SurveyAnswerAction.class);

    /** 受访者页面统一错误出口 */
    private ActionForward globalError(HttpServletRequest request, String msg) {
        request.setAttribute("errorMsg", msg);
        return new ActionForward("/global_error.jsp");
    }

    /** 重复提交不是错误, 友好告知一声 */
    private ActionForward alreadyAnswered(HttpServletRequest request) {
        request.setAttribute("already", Boolean.TRUE);
        return new ActionForward("/survey_done.jsp");
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
        logger.info("[SurveyAnswer] 受访者打开作答页, t=" + token);
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
                return alreadyAnswered(request);
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
        // 整单打印表单内容, 排障用
        dumpForm(request);
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
                return alreadyAnswered(request);
            }

            // 关卡: 输入的邮箱算出来的掩码必须和邀请里存的一致
            if (!MaskUtil.mask(email).equals(invite.getEmailMask())) {
                return globalError(request, "邮件地址与本次邀请不匹配");
            }

            SurveyQuestionMapper questionMapper = session.getMapper(SurveyQuestionMapper.class);
            List<Question> questions = questionMapper.selectBySurveyId(invite.getSurveyId());
            Map<Long, Question> questionMap = new HashMap<Long, Question>();
            for (Question q : questions) {
                // 选项列表也要加载, 否则选项内容快照会存成空串
                q.setAnswers(questionMapper.selectOptionsByQuestionId(q.getId()));
                questionMap.put(Long.valueOf(q.getId()), q);
            }

            // 反馈主记录: 谁答了哪份问卷
            SurveyFeedbackMapper feedbackMapper = session.getMapper(SurveyFeedbackMapper.class);
            SurveyFeedback feedback = new SurveyFeedback();
            feedback.setInviteUuid(invite.getUuid());
            feedback.setSurveyId(invite.getSurveyId());
            feedback.setEmail(email);
            feedbackMapper.insertFeedback(feedback);

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

                // 反馈题目行: 题干快照冗余, 以后展示不用回联 survey_question
                SurveyFeedbackQuestion fq = new SurveyFeedbackQuestion();
                fq.setFeedbackId(feedback.getId());
                fq.setQuestionId(questionId);
                fq.setQuestionContent(question.getText());
                if (question.getType() == 1) {
                    // 选择式: 值是选项ID (以后多选就是多个选项行)
                    long optionId = parseLong(value, 0);
                    if (optionId <= 0) {
                        continue;
                    }
                    String optionContent = null;
                    for (Answer option : question.getAnswers()) {
                        if (option.getId() == optionId) {
                            optionContent = option.getContent();
                            break;
                        }
                    }
                    feedbackMapper.insertFeedbackQuestion(fq);

                    SurveyFeedbackOption fo = new SurveyFeedbackOption();
                    fo.setFeedbackQuestionId(fq.getId());
                    fo.setOptionId(optionId);
                    fo.setOptionContent(optionContent == null ? "" : optionContent);
                    feedbackMapper.insertFeedbackOption(fo);
                } else {
                    // 开放式: 作答文本直接快照在题目行上
                    fq.setAnswerContent(value);
                    feedbackMapper.insertFeedbackQuestion(fq);
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

    /** 表单内容整单落日志 (一参数一行) */
    private void dumpForm(HttpServletRequest request) {
        logger.info("[SurveyAnswer] 收到作答提交, 表单内容如下:");
        Map<String, String[]> params = request.getParameterMap();
        Iterator<String> keys = params.keySet().iterator();
        while (keys.hasNext()) {
            String name = keys.next();
            String[] values = params.get(name);
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < values.length; i++) {
                if (i > 0) {
                    sb.append(", ");
                }
                sb.append(values[i]);
            }
            logger.info("[SurveyAnswer]   " + name + " = " + sb.toString());
        }
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
