package com.legacy.survey;

import java.io.Serializable;
import java.util.Date;

/**
 * 调查邀请 (uuid 对应一次受邀作答, 邮件链接里的参数全靠它)
 *
 * @author crm-dev
 * @since 2016-11-13
 */
public class SurveyInvite implements Serializable {

    private static final long serialVersionUID = 20161113L;

    /** 状态: 待发送 */
    public static final int STATUS_PENDING = 0;

    /** 状态: 已发送 */
    public static final int STATUS_SENT = 1;

    /** 状态: 已作答 */
    public static final int STATUS_ANSWERED = 2;

    private long id;

    /** 邀请码 (邮件链接用) */
    private String uuid;

    /** 问卷ID */
    private long surveyId;

    /** 受访者邮箱 */
    private String email;

    /** 邮箱加密掩码 (作答时校验用) */
    private String emailMask;

    /** 状态: 0-待发送 1-已发送 2-已作答 */
    private int status;

    private Date createTime;

    private Date sendTime;

    private Date updateTime;

    public long getId() {
        return id;
    }

    public void setId(long id) {
        this.id = id;
    }

    public String getUuid() {
        return uuid;
    }

    public void setUuid(String uuid) {
        this.uuid = uuid;
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

    public String getEmailMask() {
        return emailMask;
    }

    public void setEmailMask(String emailMask) {
        this.emailMask = emailMask;
    }

    public int getStatus() {
        return status;
    }

    public void setStatus(int status) {
        this.status = status;
    }

    public Date getCreateTime() {
        return createTime;
    }

    public void setCreateTime(Date createTime) {
        this.createTime = createTime;
    }

    public Date getSendTime() {
        return sendTime;
    }

    public void setSendTime(Date sendTime) {
        this.sendTime = sendTime;
    }

    public Date getUpdateTime() {
        return updateTime;
    }

    public void setUpdateTime(Date updateTime) {
        this.updateTime = updateTime;
    }
}
