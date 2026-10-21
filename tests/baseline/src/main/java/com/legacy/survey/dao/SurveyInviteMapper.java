package com.legacy.survey.dao;

import org.apache.ibatis.annotations.Param;

import com.legacy.survey.pojo.SurveyInvite;

/**
 * survey_invite 表的 Mapper
 *
 * @author crm-dev
 * @since 2016-11-13
 */
public interface SurveyInviteMapper {

    /** 新增邀请 */
    int insert(SurveyInvite invite);

    /** 按邀请码取 */
    SurveyInvite selectByUuid(@Param("uuid") String uuid);

    /** 标记已发送 */
    int markSent(@Param("id") long id);

    /** 标记已作答 */
    int markAnswered(@Param("id") long id);
}
