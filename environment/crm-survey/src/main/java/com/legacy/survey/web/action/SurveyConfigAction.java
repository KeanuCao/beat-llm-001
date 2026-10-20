package com.legacy.survey.web.action;

import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.List;

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
import com.legacy.survey.BaseSurveyItem;
import com.legacy.survey.Question;
import com.legacy.survey.dao.MyBatisUtil;
import com.legacy.survey.dao.SurveyQuestionMapper;

/**
 * 问卷配置保存 (Struts 1.3)
 *
 * @author crm-dev
 * @since 2006-05-20
 */
public class SurveyConfigAction extends Action {

    private static final Log logger = LogFactory.getLog(SurveyConfigAction.class);

    @Override
    public ActionForward execute(ActionMapping mapping, ActionForm form,
            HttpServletRequest request, HttpServletResponse response) throws Exception {
        try {
            // 这段后来重写过, 参数手工逐层解析
            long surveyId;
            try {
                surveyId = Long.parseLong(request.getParameter("id"));
            } catch (NumberFormatException e) {
                surveyId = 0;
            }

            List<Question> questions = new ArrayList<Question>();
            for (int i = 0; ; i++) {
                String prefix = "questions[" + i + "]";
                String idStr = request.getParameter(prefix + ".id");
                if (idStr == null) {
                    break;
                }
                Question q = new Question();
                try {
                    q.setId(Long.parseLong(idStr));
                } catch (NumberFormatException e) {
                    q.setId(0);
                }
                try {
                    q.setType(Integer.parseInt(request.getParameter(prefix + ".type")));
                } catch (NumberFormatException e) {
                    q.setType(1);
                }
                q.setText(trim(request.getParameter(prefix + ".text")));
                try {
                    q.setSort(Integer.parseInt(request.getParameter(prefix + ".sort")));
                } catch (NumberFormatException e) {
                    q.setSort(0);
                }

                // answers[j]: 勾中的选项带 id, 没勾的只有 content
                List<Answer> answers = new ArrayList<Answer>();
                for (int j = 0; ; j++) {
                    String optionPrefix = prefix + ".answers[" + j + "]";
                    String content = request.getParameter(optionPrefix + ".content");
                    String optionIdStr = request.getParameter(optionPrefix + ".id");
                    if (content == null && optionIdStr == null) {
                        break;
                    }
                    Answer a = new Answer();
                    try {
                        a.setId(optionIdStr == null ? 0 : Long.parseLong(optionIdStr));
                    } catch (NumberFormatException e) {
                        a.setId(0);
                    }
                    a.setContent(content == null ? "" : content);
                    answers.add(a);
                }
                for (int k = 0; k < answers.size(); k++) {
                    q.setAnswers(k, answers.get(k));
                }
                questions.add(q);
            }

            saveQuestions(surveyId, questions);

            // 保存完 PRG 回题目设置页 (防重复提交, 2006 年的教条)
            // 注意: forward 的 path 是 module-relative, struts 会自己补 contextPath
            return new ActionForward("/survey.do?method=questions&surveyId=" + surveyId
                    + "&msg=" + URLEncoder.encode("保存成功!", "UTF-8"), true);
        } catch (Exception e) {
            logger.error("[ERROR] Survey save failed");
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            return null;
        }
    }

    /**
     * 题目逐条入库 (survey_question / survey_question_option)
     */
    private void saveQuestions(long surveyId, List<Question> questions) {
        SqlSession session = MyBatisUtil.openSession();
        try {
            SurveyQuestionMapper mapper = session.getMapper(SurveyQuestionMapper.class);
            for (Question q : questions) {
                String text = q.getText() == null ? "" : q.getText().trim();
                if (text.length() == 0) {
                    continue;
                }
                Question row = new Question();
                row.setType(q.getType());
                row.setText(text);
                row.setSort(q.getSort());
                mapper.insertQuestion(surveyId, 0, row);

                // 选项跟着题目一起入库
                int optionSort = 1;
                for (BaseSurveyItem item : q.getAnswers()) {
                    if (!(item instanceof Answer)) {
                        continue;
                    }
                    Answer answer = (Answer) item;
                    String content = answer.getContent() == null ? "" : answer.getContent().trim();
                    if (content.length() == 0) {
                        continue;
                    }
                    mapper.insertOption(row.getId(), 0, content, optionSort++);
                }
            }
            session.commit();
        } finally {
            session.close();
        }
    }

    private static String trim(String s) {
        return s == null ? "" : s.trim();
    }
}
