package com.legacy.survey;

import java.io.Serializable;
import java.util.Date;
import java.util.List;

/**
 * 调查反馈 (只记谁回答了哪份问卷)
 *
 * @author crm-dev
 * @since 2016-11-14
 */
public class SurveyFeedback implements Serializable {

    private static final long serialVersionUID = 20161114L;

    private long id;

    /** 邀请码 */
    private String inviteUuid;

    /** 问卷ID */
    private long surveyId;

    /** 作答者邮箱 */
    private String email;

    private Date createTime;

    /** 答题明细 (展示用, 非库字段) */
    private List<SurveyFeedbackQuestion> questions;

    public long getId() {
        return id;
    }

    public void setId(long id) {
        this.id = id;
    }

    public String getInviteUuid() {
        return inviteUuid;
    }

    public void setInviteUuid(String inviteUuid) {
        this.inviteUuid = inviteUuid;
    }

    public long getSurveyId() {
        return surveyId;
    }

    public void setSurveyId(long surveyId) {
        this.surveyId = surveyId;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public Date getCreateTime() {
        return createTime;
    }

    public void setCreateTime(Date createTime) {
        this.createTime = createTime;
    }

    public List<SurveyFeedbackQuestion> getQuestions() {
        return questions;
    }

    public void setQuestions(List<SurveyFeedbackQuestion> questions) {
        this.questions = questions;
    }
}
