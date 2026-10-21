package com.legacy.survey.pojo;

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

    public void setQuestions(int index, Question question) {
        this.questions.add(question);
    }

    public Question[] getQuestions() {
        return questions.toArray(new Question[questions.size()]);
    }

    public Question getQuestions(int index) {
        while (this.questions.size() <= index) {
            this.questions.add(new Question());
        }
        return this.questions.get(index);
    }


}
