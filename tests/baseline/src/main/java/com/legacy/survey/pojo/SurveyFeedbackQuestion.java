package com.legacy.survey.pojo;

import java.io.Serializable;
import java.util.Date;
import java.util.List;

/**
 * 反馈题目 (回答了哪些题; 题干快照冗余, 展示时不回联 survey_question)
 *
 * @author crm-dev
 * @since 2016-11-14
 */
public class SurveyFeedbackQuestion implements Serializable {

    private static final long serialVersionUID = 20161114L;

    private long id;

    /** 反馈ID */
    private long feedbackId;

    /** 问卷题ID */
    private long questionId;

    /** 题干快照 (冗余) */
    private String questionContent;

    /** 题型快照: 1-单选 2-多选 3-开放式 */
    private int questionType;

    /** 开放题作答文本 (选择题为空) */
    private String answerContent;

    private Date createTime;

    /** 选项明细 (展示用, 非库字段) */
    private List<SurveyFeedbackOption> options;

    public long getId() {
        return id;
    }

    public void setId(long id) {
        this.id = id;
    }

    public long getFeedbackId() {
        return feedbackId;
    }

    public void setFeedbackId(long feedbackId) {
        this.feedbackId = feedbackId;
    }

    public long getQuestionId() {
        return questionId;
    }

    public void setQuestionId(long questionId) {
        this.questionId = questionId;
    }

    public String getQuestionContent() {
        return questionContent;
    }

    public void setQuestionContent(String questionContent) {
        this.questionContent = questionContent;
    }

    public int getQuestionType() {
        return questionType;
    }

    public void setQuestionType(int questionType) {
        this.questionType = questionType;
    }

    public String getAnswerContent() {
        return answerContent;
    }

    public void setAnswerContent(String answerContent) {
        this.answerContent = answerContent;
    }

    public Date getCreateTime() {
        return createTime;
    }

    public void setCreateTime(Date createTime) {
        this.createTime = createTime;
    }

    public List<SurveyFeedbackOption> getOptions() {
        return options;
    }

    public void setOptions(List<SurveyFeedbackOption> options) {
        this.options = options;
    }
}
