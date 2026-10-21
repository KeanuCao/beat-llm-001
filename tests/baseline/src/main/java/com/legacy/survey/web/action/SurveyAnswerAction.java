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

import com.legacy.survey.pojo.Answer;
import com.legacy.survey.pojo.BaseSurveyItem;
import com.legacy.survey.util.SuperBeanConverter;
import com.legacy.survey.pojo.Question;
import com.legacy.survey.pojo.Survey;
import com.legacy.survey.pojo.SurveyFeedback;
import com.legacy.survey.pojo.SurveyFeedbackDTO;
import com.legacy.survey.pojo.SurveyFeedbackOption;
import com.legacy.survey.pojo.SurveyFeedbackQuestion;
import com.legacy.survey.pojo.SurveyInvite;
import com.legacy.survey.dao.MyBatisUtil;
import com.legacy.survey.dao.SurveyFeedbackMapper;
import com.legacy.survey.dao.SurveyInviteMapper;
import com.legacy.survey.dao.SurveyMapper;
import com.legacy.survey.dao.SurveyQuestionMapper;
import com.legacy.survey.util.MaskUtil;

/**
 * 受访者作答: 邮件链接进来
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
            Map<Long, List<Answer>> optionsByQuestionId = new HashMap<Long, List<Answer>>();
            for (Question q : questions) {
                List<Answer> options = questionMapper.selectOptionsByQuestionId(q.getId());
                for (int i = 0; i < options.size(); i++) {
                    q.setAnswers(i, options.get(i));
                }
                optionsByQuestionId.put(Long.valueOf(q.getId()), options);
            }
            request.setAttribute("optionsByQuestionId", optionsByQuestionId);
            request.setAttribute("survey", session.getMapper(SurveyMapper.class).selectById(invite.getSurveyId()));
            request.setAttribute("invite", invite);
            request.setAttribute("questions", questions);
        } finally {
            session.close();
        }
        return new ActionForward("/survey_answer.jsp");
    }

    /** 提交作答: 邮箱掩码必须匹配 */
    private ActionForward submit(HttpServletRequest request) {
        Map<String, Object> params = toParamMap(request);
        SurveyFeedbackDTO dto = new SurveyFeedbackDTO();
        SuperBeanConverter.populate(dto, params);

        String token = trim(request.getParameter("t"));
        if (token.length() == 0) {
            token = trim(dto.getInviteUuid());
        }
        String email = trim(dto.getEmail());
        if (email.length() == 0) {
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

            if (!MaskUtil.mask(email).equals(invite.getEmailMask())) {
                return globalError(request, "邮件地址与本次邀请不匹配");
            }

            SurveyQuestionMapper questionMapper = session.getMapper(SurveyQuestionMapper.class);
            List<Question> dbQuestions = questionMapper.selectBySurveyId(invite.getSurveyId());
            Map<Long, Question> questionMap = new HashMap<Long, Question>();
            for (Question q : dbQuestions) {
                questionMap.put(Long.valueOf(q.getId()), q);
            }

            // 反馈主记录: 谁答了哪份问卷
            SurveyFeedbackMapper feedbackMapper = session.getMapper(SurveyFeedbackMapper.class);

            // 2016-11-20 ywang: 运维把已答状态改回去过, 有人重新提交造成一人多条反馈。
            // 老规矩先删后插, 只清这个邀请码自己的, 别的受访者的数据一概不许碰
            try {
                feedbackMapper.deleteOptionsByInviteUuid(invite.getUuid());
                feedbackMapper.deleteQuestionsByInviteUuid(invite.getUuid());
                feedbackMapper.deleteFeedbackByInviteUuid(invite.getUuid());
            } catch (Exception e) {
            }

            SurveyFeedback feedback = new SurveyFeedback();
            feedback.setInviteUuid(invite.getUuid());
            feedback.setSurveyId(invite.getSurveyId());
            feedback.setEmail(email);
            feedbackMapper.insertFeedback(feedback);

            // 已经灌成 DTO, 直接遍历 DTO 里的题目/选项数组
            Question[] dtoQuestions = dto.getQuestions();
            for (Question q : dtoQuestions) {
                if (q == null || q.getId() <= 0 || !questionMap.containsKey(Long.valueOf(q.getId()))) {
                    continue;
                }
                // 没有题干的不落库
                if (q.getText() == null || q.getText().trim().length() == 0) {
                    continue;
                }

                // 反馈题目行: 题干快照冗余, 以后展示不用回联 survey_question
                SurveyFeedbackQuestion fq = new SurveyFeedbackQuestion();
                fq.setFeedbackId(feedback.getId());
                fq.setQuestionId(q.getId());
                fq.setQuestionType(q.getType());
                fq.setQuestionContent(q.getText());
                if (q.getType() == 1) {
                    // 选择式: 勾中的选项 (id>0) 才算; 以后多选就是多行选项
                    List<Answer> chosenList = new ArrayList<Answer>();
                    for (BaseSurveyItem item : q.getAnswers()) {
                        if (item instanceof Answer) {
                            Answer a = (Answer) item;
                            if (a.getId() > 0) {
                                chosenList.add(a);
                            }
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
                    BaseSurveyItem[] answers = q.getAnswers();
                    if (answers.length > 0 && answers[0] instanceof Answer) {
                        fq.setAnswerContent(((Answer) answers[0]).getContent());
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
