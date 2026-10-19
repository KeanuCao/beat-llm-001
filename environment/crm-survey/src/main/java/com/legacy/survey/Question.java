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

    public String getText() {
        return text;
    }

    public void setText(String text) {
        this.text = text;
    }

    public List<Answer> getAnswers() {
        return answers;
    }

    public void setAnswers(List<Answer> answers) {
        this.answers = answers;
    }
}
