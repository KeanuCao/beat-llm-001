package com.legacy.survey;

/**
 * 受访者作答 DTO, 和后台配置的 SurveyDTO 一个路数 (继承它的嵌套结构)
 *
 * @author crm-dev
 * @since 2016-11-14
 */
public class SurveyFeedbackDTO extends SurveyDTO {

    private static final long serialVersionUID = 20161114L;

    /** 作答者邮箱 */
    private String email;

    /** 邀请码 */
    private String inviteUuid;

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getInviteUuid() {
        return inviteUuid;
    }

    public void setInviteUuid(String inviteUuid) {
        this.inviteUuid = inviteUuid;
    }
}
