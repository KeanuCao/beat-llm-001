package com.legacy.survey;

/**
 * 题目的回答/选项条目
 *
 * @author crm-dev
 * @since 2006-03-12
 */
public class Answer extends BaseSurveyItem {

    private static final long serialVersionUID = 20060313L;

    /** 回答内容 */
    private String content;

    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }
}
