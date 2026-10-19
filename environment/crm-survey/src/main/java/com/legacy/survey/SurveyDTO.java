package com.legacy.survey;

import java.util.ArrayList;
import java.util.List;

/**
 * 问卷 DTO, 表单提交和后台保存都用它
 *
 * @author crm-dev
 * @since 2006-03-15
 */
public class SurveyDTO extends BaseSurveyItem {

    private static final long serialVersionUID = 20060315L;

    /** 问卷名称 */
    private String surveyName;

    /** 问卷下的题目 */
    private List<Question> questions = new ArrayList<Question>();

    public String getSurveyName() {
        return surveyName;
    }

    public void setSurveyName(String surveyName) {
        this.surveyName = surveyName;
    }

    public void setQuestions(List<Question> questions) {
        this.questions = questions;
    }

    /**
     * 返回题目数组
     */
    public Question[] getQuestions() {
        return (Question[]) questions.toArray();
    }

    /**
     * 返回指定位置的题目
     */
    public Question getQuestions(int index) {
        return questions.get(index);
    }
}
