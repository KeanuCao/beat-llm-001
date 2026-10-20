package com.legacy.survey.dao;

import java.util.Date;
import java.util.List;

import org.apache.ibatis.annotations.Param;

import com.legacy.survey.Survey;

/**
 * survey 主表的 Mapper
 *
 * @author crm-dev
 * @since 2016-11-12
 */
public interface SurveyMapper {

    /** 问卷列表 (新的在前) */
    List<Survey> selectAll();

    /** 按主键取问卷 */
    Survey selectById(@Param("id") long id);

    /** 新增问卷 */
    int insert(Survey survey);

    /** 修改问卷 */
    int update(Survey survey);

    /** 只改状态 (publishTime 传 null 表示不动发布时间) */
    int updateStatus(@Param("id") long id, @Param("status") int status, @Param("publishTime") Date publishTime);

    /** 逻辑删除问卷 */
    int logicalDelete(@Param("id") long id);
}
