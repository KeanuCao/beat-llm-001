package com.legacy.survey.dao;

import java.util.List;

import org.apache.ibatis.annotations.Param;

import com.legacy.survey.SurveyFeedback;
import com.legacy.survey.SurveyFeedbackOption;
import com.legacy.survey.SurveyFeedbackQuestion;

/**
 * 反馈三表 (survey_feedback / survey_feedback_question / survey_feedback_option) 的 Mapper
 * 都是插入型, id 回填用于表间串联
 *
 * @author crm-dev
 * @since 2016-11-14
 */
public interface SurveyFeedbackMapper {

    /** 新增反馈 (谁答了问卷), 回填 id */
    int insertFeedback(SurveyFeedback feedback);

    /** 新增反馈题目 (题干快照), 回填 id */
    int insertFeedbackQuestion(SurveyFeedbackQuestion feedbackQuestion);

    /** 新增反馈选项 (选项快照; 多选多行), 回填 id */
    int insertFeedbackOption(SurveyFeedbackOption feedbackOption);

    /** 某问卷的全部反馈 (谁答过) */
    List<SurveyFeedback> selectBySurveyId(@Param("surveyId") long surveyId);

    /** 某份反馈的答题明细 (题干快照直接用, 不回联 survey_question) */
    List<SurveyFeedbackQuestion> selectQuestionsByFeedbackId(@Param("feedbackId") long feedbackId);

    /** 某道反馈题的选项明细 (多选时多行) */
    List<SurveyFeedbackOption> selectOptionsByFeedbackQuestionId(@Param("feedbackQuestionId") long feedbackQuestionId);
}
