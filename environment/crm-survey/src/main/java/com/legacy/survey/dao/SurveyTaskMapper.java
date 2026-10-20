package com.legacy.survey.dao;

import java.util.List;

import org.apache.ibatis.annotations.Param;

import com.legacy.survey.SurveyTask;

/**
 * survey_task 表的 Mapper (定时任务扫描用)
 *
 * @author crm-dev
 * @since 2016-11-13
 */
public interface SurveyTaskMapper {

    /** 新增任务 */
    int insert(SurveyTask task);

    /** 取待处理任务 */
    List<SurveyTask> selectPending(@Param("limit") int limit);

    /** 标记完成 */
    int markDone(@Param("id") long id);

    /** 标记失败 */
    int markFailed(@Param("id") long id, @Param("errorMsg") String errorMsg);
}
