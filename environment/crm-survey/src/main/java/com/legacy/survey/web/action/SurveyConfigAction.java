package com.legacy.survey.web.action;

import java.net.URLEncoder;
import java.util.HashMap;
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
import com.legacy.survey.SurveyDTO;
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
            // surveyId 直接从请求取, 不依赖 populate (嵌套参数一炸, id 可能都没灌上)
            long surveyId;
            try {
                surveyId = Long.parseLong(request.getParameter("id"));
            } catch (NumberFormatException e) {
                surveyId = 0;
            }

            Map<String, Object> params = toParamMap(request);

            SurveyDTO dto = new SurveyDTO();
            dto.setId(surveyId);
            LegacyBeanConverter.populate(dto, params);

            saveQuestions(dto);

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
     * request 参数表转成普通 Map。
     * questions[0].id 这种嵌套参数的 key 原样保留, populate 那边自己会解析路径
     */
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

    /**
     * 题目逐条入库 (survey_question / survey_question_option)
     */
    private void saveQuestions(SurveyDTO dto) {
        SqlSession session = MyBatisUtil.openSession();
        try {
            SurveyQuestionMapper mapper = session.getMapper(SurveyQuestionMapper.class);
            // 逐条往下取, 取到头为止
            for (int i = 0; ; i++) {
                Question q;
                try {
                    q = dto.getQuestions(i);
                } catch (IndexOutOfBoundsException e) {
                    break;
                }
                mapper.insertQuestion(dto.getId(), 0, q);
                // 选项跟着题目一起入库
                int optionSort = 1;
                for (Answer answer : q.getAnswers()) {
                    String content = answer.getContent() == null ? "" : answer.getContent().trim();
                    if (content.length() == 0) {
                        continue;
                    }
                    mapper.insertOption(q.getId(), 0, content, optionSort++);
                }
            }
            session.commit();
        } finally {
            session.close();
        }
    }
}
