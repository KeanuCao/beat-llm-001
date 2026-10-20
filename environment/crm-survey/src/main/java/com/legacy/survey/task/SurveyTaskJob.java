package com.legacy.survey.task;

import java.util.List;
import java.util.UUID;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.ibatis.session.SqlSession;

import com.legacy.survey.Survey;
import com.legacy.survey.SurveyInvite;
import com.legacy.survey.SurveyTask;
import com.legacy.survey.dao.MyBatisUtil;
import com.legacy.survey.dao.SurveyInviteMapper;
import com.legacy.survey.dao.SurveyMapper;
import com.legacy.survey.dao.SurveyTaskMapper;
import com.legacy.survey.util.MailUtil;
import com.legacy.survey.util.MaskUtil;

/**
 * 调查任务执行器: 扫任务表 -> 每个邮箱生成 uuid 邀请 -> 落一封 .eml
 *
 * @author crm-dev
 * @since 2016-11-13
 */
public class SurveyTaskJob implements Runnable {

    private static final Log logger = LogFactory.getLog(SurveyTaskJob.class);

    public void run() {
        SqlSession session = MyBatisUtil.openSession();
        try {
            SurveyTaskMapper taskMapper = session.getMapper(SurveyTaskMapper.class);
            List<SurveyTask> tasks = taskMapper.selectPending(50);
            for (SurveyTask task : tasks) {
                try {
                    process(session, task);
                    taskMapper.markDone(task.getId());
                } catch (Exception e) {
                    logger.error("[ERROR] survey task " + task.getId() + " failed");
                    taskMapper.markFailed(task.getId(), e.getMessage() == null ? "unknown" : e.getMessage());
                }
            }
            session.commit();
        } catch (Exception e) {
            logger.error("[ERROR] survey task poll failed");
        } finally {
            session.close();
        }
    }

    private void process(SqlSession session, SurveyTask task) throws Exception {
        SurveyMapper surveyMapper = session.getMapper(SurveyMapper.class);
        SurveyInviteMapper inviteMapper = session.getMapper(SurveyInviteMapper.class);

        Survey survey = surveyMapper.selectById(task.getSurveyId());
        if (survey == null) {
            throw new RuntimeException("survey " + task.getSurveyId() + " not found");
        }

        int sent = 0;
        String[] emails = task.getEmails().split("[,;，；\\s]+");
        for (int i = 0; i < emails.length; i++) {
            String email = emails[i] == null ? "" : emails[i].trim();
            if (email.length() == 0 || email.indexOf('@') < 0) {
                continue;
            }
            String uuid = UUID.randomUUID().toString().replace("-", "");

            SurveyInvite invite = new SurveyInvite();
            invite.setUuid(uuid);
            invite.setSurveyId(task.getSurveyId());
            invite.setEmail(email);
            invite.setEmailMask(MaskUtil.mask(email));
            invite.setStatus(SurveyInvite.STATUS_PENDING);
            inviteMapper.insert(invite);

            String link = MailUtil.getBaseUrl() + "/surveyAnswer.do?t=" + uuid;
            MailUtil.sendInvitation(survey, task.getStartDate(), task.getEndDate(), email, uuid, link);

            inviteMapper.markSent(invite.getId());
            sent++;
        }
        if (sent == 0) {
            throw new RuntimeException("邮件列表为空或格式不合法");
        }
    }
}
