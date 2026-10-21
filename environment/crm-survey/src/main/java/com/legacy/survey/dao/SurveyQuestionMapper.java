package com.legacy.survey.dao;

import java.util.List;

import org.apache.ibatis.annotations.Param;

import com.legacy.survey.pojo.Question;
import com.legacy.survey.pojo.Answer;

/**
 * survey_question / survey_question_option 表的 Mapper (iBatis 升 MyBatis 3.2 之后改成接口式)
 *
 * 2013-11-08  liqiang   建文件
 * 2014-03-12  wangwei   逻辑删除改造
 *
 * @author liqiang
 * @since 2013-11-08
 */
public interface SurveyQuestionMapper {

    /**
     * 插一条问卷题目, 新 id 回填到 q.id
     */
    int insertQuestion(@Param("surveyId") long surveyId,
                       @Param("standardQuestionId") long standardQuestionId,
                       @Param("q") Question q);

    /**
     * 插一条问卷题选项
     */
    int insertOption(@Param("surveyQuestionId") long surveyQuestionId,
                     @Param("standardQuestionOptionId") long standardQuestionOptionId,
                     @Param("content") String content,
                     @Param("sortNo") int sortNo);

    /** 某问卷的题目列表 (按 sort_no) */
    List<Question> selectBySurveyId(@Param("surveyId") long surveyId);

    /** 某问卷题的选项列表 (按 sort_no) */
    List<Answer> selectOptionsByQuestionId(@Param("surveyQuestionId") long surveyQuestionId);

    /** 某问卷题目数 (排序号顺延用) */
    int countBySurveyId(@Param("surveyId") long surveyId);
}
