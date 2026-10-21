package com.legacy.survey.pojo;

import java.io.Serializable;

/**
 * 问卷条目基类, 题目/选项/问卷的公共字段都在这里
 *
 * @author crm-dev
 * @since 2006-03-12
 */
public abstract class BaseSurveyItem implements Serializable {

    private static final long serialVersionUID = 20060312L;

    /** 主键 */
    private long id;

    /** 类型: 1-单选 2-多选 3-问答 */
    private int type;

    /** 排序号 */
    private int sort;

    public long getId() {
        return id;
    }

    public void setId(long id) {
        this.id = id;
    }

    public int getType() {
        return type;
    }

    public void setType(int type) {
        this.type = type;
    }

    public int getSort() {
        return sort;
    }

    public void setSort(int sort) {
        this.sort = sort;
    }
}
