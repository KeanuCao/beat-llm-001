package com.legacy.survey.web.action;

import java.net.URLEncoder;
import java.text.SimpleDateFormat;
import java.util.Date;
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
import com.legacy.survey.Survey;
import com.legacy.survey.SurveyFeedback;
import com.legacy.survey.SurveyFeedbackOption;
import com.legacy.survey.SurveyFeedbackQuestion;
import com.legacy.survey.SurveyTask;
import com.legacy.survey.User;
import com.legacy.survey.dao.MyBatisUtil;
import com.legacy.survey.dao.StandardQuestionMapper;
import com.legacy.survey.dao.SurveyFeedbackMapper;
import com.legacy.survey.dao.SurveyMapper;
import com.legacy.survey.dao.SurveyQuestionMapper;
import com.legacy.survey.dao.SurveyTaskMapper;
import com.legacy.survey.web.LoginCheckFilter;

/**
 * 问卷管理: 创建 Survey、从题库选入题目、自定义题目在配置页走老链路、开始调查
 *
 * @author crm-dev
 * @since 2016-11-12
 */
public class SurveyAction extends DispatchAction {

    /** 问卷列表 */
    public ActionForward list(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        SqlSession session = MyBatisUtil.openSession();
        try {
            request.setAttribute("surveys", session.getMapper(SurveyMapper.class).selectAll());
        } finally {
            session.close();
        }
        String msg = request.getParameter("msg");
        if (msg != null && msg.trim().length() > 0) {
            request.setAttribute("msg", msg);
        }
        return new ActionForward("/survey_list.jsp");
    }

    /** 打开新增/编辑问卷页 */
    public ActionForward edit(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        long id = parseLong(request.getParameter("id"), 0);
        if (id > 0) {
            SqlSession session = MyBatisUtil.openSession();
            try {
                request.setAttribute("survey", session.getMapper(SurveyMapper.class).selectById(id));
            } finally {
                session.close();
            }
        }
        return new ActionForward("/survey_edit.jsp");
    }

    /** 保存问卷 (新增或修改), 保存完进题目设置页 */
    public ActionForward save(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        long id = parseLong(request.getParameter("id"), 0);
        String title = trim(request.getParameter("title"));
        String description = trim(request.getParameter("description"));

        if (title.length() == 0) {
            request.setAttribute("errorMsg", "问卷标题不能为空");
            return new ActionForward("/survey_edit.jsp");
        }

        long surveyId;
        SqlSession session = MyBatisUtil.openSession();
        try {
            SurveyMapper mapper = session.getMapper(SurveyMapper.class);
            if (id > 0) {
                Survey survey = mapper.selectById(id);
                if (survey == null) {
                    session.close();
                    return redirectWithMsg("/survey.do?method=list", "问卷不存在");
                }
                survey.setTitle(title);
                survey.setDescription(description);
                mapper.update(survey);
                surveyId = id;
            } else {
                Survey survey = new Survey();
                survey.setTitle(title);
                survey.setDescription(description);
                survey.setStatus(Survey.STATUS_DRAFT);
                User loginUser = (User) request.getSession().getAttribute(LoginCheckFilter.SESSION_USER_KEY);
                survey.setCreatorId(loginUser == null ? 0 : loginUser.getId());
                mapper.insert(survey);
                surveyId = survey.getId();
            }
            session.commit();
        } finally {
            session.close();
        }
        return new ActionForward("/survey.do?method=questions&surveyId=" + surveyId, true);
    }

    /** 题目设置页 (从题库选入 / 自定义题目 / 开始调查) */
    public ActionForward questions(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        long surveyId = parseLong(request.getParameter("surveyId"), 0);
        SqlSession session = MyBatisUtil.openSession();
        try {
            SurveyMapper surveyMapper = session.getMapper(SurveyMapper.class);
            SurveyQuestionMapper questionMapper = session.getMapper(SurveyQuestionMapper.class);
            Survey survey = surveyMapper.selectById(surveyId);
            if (survey == null) {
                session.close();
                return redirectWithMsg("/survey.do?method=list", "问卷不存在");
            }
            List<Question> questions = questionMapper.selectBySurveyId(surveyId);
            for (Question q : questions) {
                q.setAnswers(questionMapper.selectOptionsByQuestionId(q.getId()));
            }
            request.setAttribute("survey", survey);
            request.setAttribute("questions", questions);
            request.setAttribute("nextSort", questionMapper.countBySurveyId(surveyId) + 1);
        } finally {
            session.close();
        }
        String msg = request.getParameter("msg");
        if (msg != null && msg.trim().length() > 0) {
            request.setAttribute("msg", msg);
        }
        return new ActionForward("/survey_questions.jsp");
    }

    /** 开始调查 (第一步): 进调查配置页, 填起止日期和受访者邮件列表 */
    public ActionForward start(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        long surveyId = parseLong(request.getParameter("surveyId"), 0);
        SqlSession session = MyBatisUtil.openSession();
        try {
            SurveyMapper mapper = session.getMapper(SurveyMapper.class);
            Survey survey = mapper.selectById(surveyId);
            if (survey == null) {
                session.close();
                return redirectWithMsg("/survey.do?method=list", "问卷不存在");
            }
            if (session.getMapper(SurveyQuestionMapper.class).countBySurveyId(surveyId) == 0) {
                session.close();
                return redirectWithMsg("/survey.do?method=questions&surveyId=" + surveyId, "一道题都没有, 先去设置题目");
            }
            request.setAttribute("survey", survey);
        } finally {
            session.close();
        }
        return new ActionForward("/survey_start.jsp");
    }

    /** 开始调查 (第二步): 写异步任务表, Tomcat 里的定时任务每分钟扫表发信 */
    public ActionForward launch(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        long surveyId = parseLong(request.getParameter("surveyId"), 0);
        String startDateStr = trim(request.getParameter("startDate"));
        String endDateStr = trim(request.getParameter("endDate"));
        String emails = trim(request.getParameter("emails"));

        SimpleDateFormat fmt = new SimpleDateFormat("yyyy-MM-dd");
        Date startDate = null;
        Date endDate = null;
        try {
            startDate = fmt.parse(startDateStr);
            endDate = fmt.parse(endDateStr);
        } catch (Exception e) {
            request.setAttribute("errorMsg", "日期格式不对, 请用 yyyy-MM-dd");
        }
        if (startDate != null && endDate != null && endDate.before(startDate)) {
            request.setAttribute("errorMsg", "结束日期不能早于开始日期");
        }
        if (emails.length() == 0) {
            request.setAttribute("errorMsg", "受访者邮件列表不能为空");
        }
        if (request.getAttribute("errorMsg") != null) {
            SqlSession preload = MyBatisUtil.openSession();
            try {
                request.setAttribute("survey", preload.getMapper(SurveyMapper.class).selectById(surveyId));
            } finally {
                preload.close();
            }
            return new ActionForward("/survey_start.jsp");
        }

        SqlSession session = MyBatisUtil.openSession();
        try {
            SurveyMapper surveyMapper = session.getMapper(SurveyMapper.class);
            Survey survey = surveyMapper.selectById(surveyId);
            if (survey == null) {
                session.close();
                return redirectWithMsg("/survey.do?method=list", "问卷不存在");
            }

            // 问卷置为已发布, 调查信息写异步任务表
            surveyMapper.updateStatus(surveyId, Survey.STATUS_PUBLISHED, new Date());

            SurveyTask task = new SurveyTask();
            task.setSurveyId(surveyId);
            task.setStartDate(startDate);
            task.setEndDate(endDate);
            task.setEmails(emails);
            task.setStatus(SurveyTask.STATUS_PENDING);
            session.getMapper(SurveyTaskMapper.class).insert(task);

            session.commit();
        } finally {
            session.close();
        }
        return redirectWithMsg("/survey.do?method=questions&surveyId=" + surveyId, "调查任务已提交, 定时任务每分钟扫描任务表后发出邀请邮件");
    }

    /** 调查进行页 (作答视图) */
    public ActionForward run(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        long surveyId = parseLong(request.getParameter("surveyId"), 0);
        SqlSession session = MyBatisUtil.openSession();
        try {
            SurveyMapper surveyMapper = session.getMapper(SurveyMapper.class);
            SurveyQuestionMapper questionMapper = session.getMapper(SurveyQuestionMapper.class);
            Survey survey = surveyMapper.selectById(surveyId);
            if (survey == null) {
                session.close();
                return redirectWithMsg("/survey.do?method=list", "问卷不存在");
            }
            List<Question> questions = questionMapper.selectBySurveyId(surveyId);
            for (Question q : questions) {
                q.setAnswers(questionMapper.selectOptionsByQuestionId(q.getId()));
            }
            request.setAttribute("survey", survey);
            request.setAttribute("questions", questions);
        } finally {
            session.close();
        }
        return new ActionForward("/survey_run.jsp");
    }

    /** 从题库选入的入口页 */
    public ActionForward pickPage(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        long surveyId = parseLong(request.getParameter("surveyId"), 0);
        SqlSession session = MyBatisUtil.openSession();
        try {
            request.setAttribute("questions", session.getMapper(StandardQuestionMapper.class).selectAll());
        } finally {
            session.close();
        }
        request.setAttribute("surveyId", surveyId);
        return new ActionForward("/bank_pick.jsp");
    }

    /** 从标准题库选入一道题 (连选项一起复制) */
    public ActionForward pickBank(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        long surveyId = parseLong(request.getParameter("surveyId"), 0);
        long questionId = parseLong(request.getParameter("questionId"), 0);

        SqlSession session = MyBatisUtil.openSession();
        try {
            StandardQuestionMapper bankMapper = session.getMapper(StandardQuestionMapper.class);
            SurveyQuestionMapper questionMapper = session.getMapper(SurveyQuestionMapper.class);

            Question bankQuestion = bankMapper.selectById(questionId);
            if (bankQuestion == null) {
                session.close();
                return redirectWithMsg("/survey.do?method=questions&surveyId=" + surveyId, "题目不存在");
            }
            Question q = new Question();
            q.setType(bankQuestion.getType());
            q.setText(bankQuestion.getText());
            q.setIsRequired(bankQuestion.getIsRequired());
            q.setSort(questionMapper.countBySurveyId(surveyId) + 1);
            questionMapper.insertQuestion(surveyId, questionId, q);
            for (Answer option : bankMapper.selectOptionsByQuestionId(questionId)) {
                questionMapper.insertOption(q.getId(), option.getId(), option.getContent(), option.getSort());
            }
            session.commit();
        } finally {
            session.close();
        }
        return new ActionForward("/survey.do?method=questions&surveyId=" + surveyId, true);
    }

    /** 回答详情: 谁答了, 都答了什么 (快照三表直接读, 不回联 survey_question) */
    public ActionForward feedback(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        long surveyId = parseLong(request.getParameter("surveyId"), 0);
        SqlSession session = MyBatisUtil.openSession();
        try {
            SurveyMapper surveyMapper = session.getMapper(SurveyMapper.class);
            SurveyFeedbackMapper feedbackMapper = session.getMapper(SurveyFeedbackMapper.class);
            Survey survey = surveyMapper.selectById(surveyId);
            if (survey == null) {
                session.close();
                return redirectWithMsg("/survey.do?method=list", "问卷不存在");
            }
            List<SurveyFeedback> feedbacks = feedbackMapper.selectBySurveyId(surveyId);
            for (SurveyFeedback fb : feedbacks) {
                List<SurveyFeedbackQuestion> fqs = feedbackMapper.selectQuestionsByFeedbackId(fb.getId());
                for (SurveyFeedbackQuestion fq : fqs) {
                    fq.setOptions(feedbackMapper.selectOptionsByFeedbackQuestionId(fq.getId()));
                }
                fb.setQuestions(fqs);
            }
            request.setAttribute("survey", survey);
            request.setAttribute("feedbacks", feedbacks);
        } finally {
            session.close();
        }
        return new ActionForward("/survey_feedback.jsp");
    }

    /** 删除问卷 (逻辑删) */
    public ActionForward delete(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {

        long id = parseLong(request.getParameter("id"), 0);
        SqlSession session = MyBatisUtil.openSession();
        try {
            session.getMapper(SurveyMapper.class).logicalDelete(id);
            session.commit();
        } finally {
            session.close();
        }
        return redirectWithMsg("/survey.do?method=list", "已删除");
    }

    private ActionForward redirectWithMsg(String target, String msg) throws Exception {
        String separator = target.indexOf('?') >= 0 ? "&" : "?";
        return new ActionForward(target + separator + "msg=" + URLEncoder.encode(msg, "UTF-8"), true);
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
