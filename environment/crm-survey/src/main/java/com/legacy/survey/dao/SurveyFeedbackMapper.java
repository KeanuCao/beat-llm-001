package com.legacy.survey.dao;

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
}
