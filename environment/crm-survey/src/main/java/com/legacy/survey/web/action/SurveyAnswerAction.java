package com.legacy.survey.web.action;

import java.util.ArrayList;
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
import com.legacy.survey.LegacyBeanConverter;
import com.legacy.survey.Question;
import com.legacy.survey.SurveyFeedback;
import com.legacy.survey.SurveyFeedbackDTO;
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

    /** 提交作答: 表单先绑成 SurveyFeedbackDTO (和后台配置一个路数), 邮箱掩码必须匹配 */
    private ActionForward submit(HttpServletRequest request) {
        // 整单打印表单内容, 排障用
        dumpForm(request);

        Map<String, Object> params = toParamMap(request);
        SurveyFeedbackDTO dto = new SurveyFeedbackDTO();
        LegacyBeanConverter.populate(dto, params);

        String token = trim(request.getParameter("t"));
        if (token.length() == 0) {
            token = trim(dto.getInviteUuid());
        }
        String email = trim(dto.getEmail());
        if (email.length() == 0) {
            // 邮箱是核对身份的, 绑定丢了就从请求里兜底拿
            email = trim(request.getParameter("email"));
        }
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

            // 库里有这道题才算数 (防乱编 id)
            SurveyQuestionMapper questionMapper = session.getMapper(SurveyQuestionMapper.class);
            List<Question> dbQuestions = questionMapper.selectBySurveyId(invite.getSurveyId());
            Map<Long, Question> questionMap = new HashMap<Long, Question>();
            for (Question q : dbQuestions) {
                questionMap.put(Long.valueOf(q.getId()), q);
            }

            // 反馈主记录: 谁答了哪份问卷
            SurveyFeedbackMapper feedbackMapper = session.getMapper(SurveyFeedbackMapper.class);
            SurveyFeedback feedback = new SurveyFeedback();
            feedback.setInviteUuid(invite.getUuid());
            feedback.setSurveyId(invite.getSurveyId());
            feedback.setEmail(email);
            feedbackMapper.insertFeedback(feedback);

            // 逐题往下取, 取到头为止 (和配置保存一个路数)
            for (int i = 0; ; i++) {
                Question q;
                try {
                    q = dto.getQuestions(i);
                } catch (IndexOutOfBoundsException e) {
                    break;
                }
                if (q == null || q.getId() <= 0 || !questionMap.containsKey(Long.valueOf(q.getId()))) {
                    continue;
                }

                // 反馈题目行: 题干快照冗余, 以后展示不用回联 survey_question
                SurveyFeedbackQuestion fq = new SurveyFeedbackQuestion();
                fq.setFeedbackId(feedback.getId());
                fq.setQuestionId(q.getId());
                fq.setQuestionContent(q.getText());
                if (q.getType() == 1) {
                    // 选择式: 勾中的选项 (id>0) 才算; 以后多选就是多行选项
                    List<Answer> chosenList = new ArrayList<Answer>();
                    for (Answer a : q.getAnswers()) {
                        if (a != null && a.getId() > 0) {
                            chosenList.add(a);
                        }
                    }
                    if (chosenList.isEmpty()) {
                        continue;
                    }
                    feedbackMapper.insertFeedbackQuestion(fq);
                    for (Answer a : chosenList) {
                        SurveyFeedbackOption fo = new SurveyFeedbackOption();
                        fo.setFeedbackQuestionId(fq.getId());
                        fo.setOptionId(a.getId());
                        fo.setOptionContent(a.getContent() == null ? "" : a.getContent());
                        feedbackMapper.insertFeedbackOption(fo);
                    }
                } else {
                    // 开放式: 作答文本直接快照在题目行上
                    if (q.getAnswers().size() > 0 && q.getAnswers().get(0) != null) {
                        fq.setAnswerContent(q.getAnswers().get(0).getContent());
                    }
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

    /** 参数表扁平化: 嵌套 key 原样保留, populate 自己解析路径 */
    private Map<String, Object> toParamMap(HttpServletRequest request) {
        Map<String, String[]> raw = request.getParameterMap();
        Map<String, Object> params = new HashMap<String, Object>();
        for (Map.Entry<String, String[]> entry : raw.entrySet()) {
            String[] values = entry.getValue();
            if (values.length == 1) {
                params.put(entry.getKey(), values[0]);
            } else {
                params.put(entry.getKey(), values);
            }
        }
        return params;
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
