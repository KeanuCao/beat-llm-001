package com.legacy.survey;

import java.io.Serializable;
import java.util.Date;

/**
 * 调查任务 (异步发信, 定时任务扫描这张表)
 *
 * @author crm-dev
 * @since 2016-11-13
 */
public class SurveyTask implements Serializable {

    private static final long serialVersionUID = 20161113L;

    /** 状态: 待处理 */
    public static final int STATUS_PENDING = 0;

    /** 状态: 已完成 */
    public static final int STATUS_DONE = 1;

    /** 状态: 失败 */
    public static final int STATUS_FAILED = 2;

    private long id;

    /** 问卷ID */
    private long surveyId;

    /** 调查开始时间 */
    private Date startDate;

    /** 调查结束时间 */
    private Date endDate;

    /** 受访者邮件列表 (原始串) */
    private String emails;

    /** 状态: 0-待处理 1-已完成 2-失败 */
    private int status;

    /** 失败原因 */
    private String errorMsg;

    private Date sendTime;

    private Date createTime;

    private Date updateTime;

    public long getId() {
        return id;
    }

    public void setId(long id) {
        this.id = id;
    }

    public long getSurveyId() {
        return surveyId;
    }

    public void setSurveyId(long surveyId) {
        this.surveyId = surveyId;
    }

    public Date getStartDate() {
        return startDate;
    }

    public void setStartDate(Date startDate) {
        this.startDate = startDate;
    }

    public Date getEndDate() {
        return endDate;
    }

    public void setEndDate(Date endDate) {
        this.endDate = endDate;
    }

    public String getEmails() {
        return emails;
    }

    public void setEmails(String emails) {
        this.emails = emails;
    }

    public int getStatus() {
        return status;
    }

    public void setStatus(int status) {
        this.status = status;
    }

    public String getErrorMsg() {
        return errorMsg;
    }

    public void setErrorMsg(String errorMsg) {
        this.errorMsg = errorMsg;
    }

    public Date getSendTime() {
        return sendTime;
    }

    public void setSendTime(Date sendTime) {
        this.sendTime = sendTime;
    }

    public Date getCreateTime() {
        return createTime;
    }

    public void setCreateTime(Date createTime) {
        this.createTime = createTime;
    }

    public Date getUpdateTime() {
        return updateTime;
    }

    public void setUpdateTime(Date updateTime) {
        this.updateTime = updateTime;
    }
}
