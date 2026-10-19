package com.legacy.survey.web;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.ibatis.session.SqlSession;

import com.legacy.survey.LegacyBeanConverter;
import com.legacy.survey.Question;
import com.legacy.survey.SurveyDTO;
import com.legacy.survey.dao.MyBatisUtil;
import com.legacy.survey.dao.SurveyQuestionMapper;

/**
 * 问卷配置保存
 *
 * @author crm-dev
 * @since 2006-05-20
 */
public class SurveyConfigServlet extends HttpServlet {

    private static final long serialVersionUID = 20060520L;

    private static final Log logger = LogFactory.getLog(SurveyConfigServlet.class);

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        response.sendRedirect(request.getContextPath() + "/survey_config.jsp");
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        try {
            Map<String, Object> params = toParamMap(request);

            SurveyDTO dto = new SurveyDTO();
            LegacyBeanConverter.populate(dto, params);

            saveQuestions(dto);

            // 保存完重定向回配置页, 防止表单重复提交 (PRG, 2006 年的教条)
            response.sendRedirect(request.getContextPath() + "/survey_config.jsp?saved=1");
        } catch (Exception e) {
            logger.error("[ERROR] Survey save failed");
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
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
     * 题目逐条入库 (survey_question 表)
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
                mapper.insertSurveyQuestion(dto.getId(), q.getType(), q.getText(), q.getSort());
            }
            session.commit();
        } finally {
            session.close();
        }
    }
}
