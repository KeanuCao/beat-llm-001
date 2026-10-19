package com.legacy.survey.dao;

import org.apache.ibatis.annotations.Param;

/**
 * survey_question 表的 Mapper (iBatis 升 MyBatis 3.2 之后改成接口式)
 *
 * @author crm-dev
 * @since 2013-11-08
 */
public interface SurveyQuestionMapper {

    /**
     * 插一条问卷题目
     */
    int insertSurveyQuestion(@Param("surveyId") long surveyId,
                             @Param("questionType") int questionType,
                             @Param("content") String content,
                             @Param("sortNo") int sortNo);
}
