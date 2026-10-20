package com.legacy.survey.dao;

import java.util.List;

import org.apache.ibatis.annotations.Param;

import com.legacy.survey.Answer;
import com.legacy.survey.Question;

/**
 * 标准题库 (standard_question / standard_question_option) 的 Mapper
 *
 * @author crm-dev
 * @since 2016-11-11
 */
public interface StandardQuestionMapper {

    /** 题库全量列表 */
    List<Question> selectAll();

    /** 按主键取题 (不含选项) */
    Question selectById(@Param("id") long id);

    /** 取题下的选项 */
    List<Answer> selectOptionsByQuestionId(@Param("standardQuestionId") long standardQuestionId);

    /** 新增题目 */
    int insert(Question question);

    /** 新增选项 */
    int insertOption(@Param("standardQuestionId") long standardQuestionId,
                     @Param("content") String content,
                     @Param("sortNo") int sortNo);

    /** 修改题目 */
    int update(Question question);

    /** 逻辑删除题目 */
    int logicalDelete(@Param("id") long id);

    /** 物理删除题目下的选项 (改题/删题时先清后插用) */
    int deleteOptionsByQuestionId(@Param("standardQuestionId") long standardQuestionId);
}
