package com.legacy.survey;

import java.io.Serializable;
import java.util.Date;

/**
 * 反馈选项 (选择式的选择结果; 以后多选题就是多行)
 *
 * @author crm-dev
 * @since 2016-11-14
 */
public class SurveyFeedbackOption implements Serializable {

    private static final long serialVersionUID = 20161114L;

    private long id;

    /** 反馈题ID */
    private long feedbackQuestionId;

    /** 选项ID (survey_question_option.id) */
    private long optionId;

    /** 选项内容快照 (冗余) */
    private String optionContent;

    private Date createTime;

    public long getId() {
        return id;
    }

    public void setId(long id) {
        this.id = id;
    }

    public long getFeedbackQuestionId() {
        return feedbackQuestionId;
    }

    public void setFeedbackQuestionId(long feedbackQuestionId) {
        this.feedbackQuestionId = feedbackQuestionId;
    }

    public long getOptionId() {
        return optionId;
    }

    public void setOptionId(long optionId) {
        this.optionId = optionId;
    }

    public String getOptionContent() {
        return optionContent;
    }

    public void setOptionContent(String optionContent) {
        this.optionContent = optionContent;
    }

    public Date getCreateTime() {
        return createTime;
    }

    public void setCreateTime(Date createTime) {
        this.createTime = createTime;
    }
}
