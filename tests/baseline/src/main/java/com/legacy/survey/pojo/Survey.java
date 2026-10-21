package com.legacy.survey.pojo;

import java.io.Serializable;
import java.util.Date;

/**
 * 问卷
 *
 * @author crm-dev
 * @since 2016-11-12
 */
public class Survey implements Serializable {

    private static final long serialVersionUID = 20161112L;

    /** 状态: 草稿 */
    public static final int STATUS_DRAFT = 0;

    /** 状态: 已发布 */
    public static final int STATUS_PUBLISHED = 1;

    /** 状态: 已下线 */
    public static final int STATUS_OFFLINE = 2;

    private long id;

    /** 问卷标题 */
    private String title;

    /** 问卷说明 */
    private String description;

    /** 状态: 0-草稿 1-已发布 2-已下线 */
    private int status;

    /** 创建人ID */
    private long creatorId;

    /** 发布时间 */
    private Date publishTime;

    private Date createTime;

    private Date updateTime;

    public long getId() {
        return id;
    }

    public void setId(long id) {
        this.id = id;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public int getStatus() {
        return status;
    }

    public void setStatus(int status) {
        this.status = status;
    }

    public long getCreatorId() {
        return creatorId;
    }

    public void setCreatorId(long creatorId) {
        this.creatorId = creatorId;
    }

    public Date getPublishTime() {
        return publishTime;
    }

    public void setPublishTime(Date publishTime) {
        this.publishTime = publishTime;
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
