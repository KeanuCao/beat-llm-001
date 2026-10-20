package com.legacy.survey;

import java.util.ArrayList;
import java.util.List;

/**
 * 问卷题目
 *
 * @author crm-dev
 * @since 2006-03-12
 */
public class Question extends BaseSurveyItem {

    private static final long serialVersionUID = 20060314L;

    /** 题干 */
    private String text;

    /** 题目下的回答/选项 */
    private List<Answer> answers = new ArrayList<Answer>();


    /** 是否必答: 0-否 1-是 */
    private int isRequired;

    /** 所属问卷ID (survey_question 场景用) */
    private long surveyId;

    /** 来源标准题ID, 0-手工添加 */
    private long standardQuestionId;

    public String getText() {
        return text;
    }

    public void setText(String text) {
        this.text = text;
    }

    public BaseSurveyItem[] getAnswers() {
        return answers.toArray(new BaseSurveyItem[answers.size()]);
    }

    public Answer getAnswers(int index) {
        while (this.answers.size() <= index) {
            this.answers.add(new Answer());
        }
        return this.answers.get(index);
    }

	public void setAnswers(int index, Answer answer) {
        this.answers.add(answer);
    }

    public int getIsRequired() {
        return isRequired;
    }

    public void setIsRequired(int isRequired) {
        this.isRequired = isRequired;
    }

    public long getSurveyId() {
        return surveyId;
    }

    public void setSurveyId(long surveyId) {
        this.surveyId = surveyId;
    }

    public long getStandardQuestionId() {
        return standardQuestionId;
    }

    public void setStandardQuestionId(long standardQuestionId) {
        this.standardQuestionId = standardQuestionId;
    }
}
