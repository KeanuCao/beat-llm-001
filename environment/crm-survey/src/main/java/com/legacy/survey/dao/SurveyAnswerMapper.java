package com.legacy.survey.dao;

import org.apache.ibatis.annotations.Param;

/**
 * survey_answer 表的 Mapper
 *
 * @author crm-dev
 * @since 2016-11-13
 */
public interface SurveyAnswerMapper {

    /** 插一条回答明细 */
    int insert(@Param("inviteUuid") String inviteUuid,
               @Param("surveyId") long surveyId,
               @Param("questionId") long questionId,
               @Param("answerOptionId") long answerOptionId,
               @Param("answerContent") String answerContent,
               @Param("email") String email);
}
