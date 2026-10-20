package com.legacy.survey.util;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.nio.charset.Charset;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Properties;

import javax.mail.Authenticator;
import javax.mail.Message;
import javax.mail.PasswordAuthentication;
import javax.mail.Session;
import javax.mail.Transport;
import javax.mail.internet.InternetAddress;
import javax.mail.internet.MimeMessage;

import com.legacy.survey.Survey;

/**
 * 邮件投递: SMTP 真发; 发出去的顺手留档一份 .eml (当年网关扫盘的老习惯, 现在留底备查)
 *
 * @author crm-dev
 * @since 2016-11-13
 */
public final class MailUtil {

    private static final Properties CONFIG = loadConfig();

    private MailUtil() {
    }

    private static Properties loadConfig() {
        Properties p = new Properties();
        try {
            p.load(MailUtil.class.getResourceAsStream("/mail.properties"));
        } catch (Exception e) {
            // 配置读不到就用默认值, 别把发信链路卡死
        }
        return p;
    }

    public static String getBaseUrl() {
        return CONFIG.getProperty("mail.base.url", "http://localhost:8080/crm-survey");
    }

    /**
     * 真发一封邀请邮件 (SMTP)。
     * 发送失败直接往外抛, 任务层会记失败; 成功后留档 .eml 并返回留档路径
     */
    public static String sendInvitation(Survey survey, Date startDate, Date endDate,
                                        String email, String uuid, String link) throws Exception {

        SimpleDateFormat fmt = new SimpleDateFormat("yyyy-MM-dd");
        String body = "尊敬的客户:\r\n"
                + "    我们正在进行 \"" + survey.getTitle() + "\" 调查, 期待您的宝贵意见。\r\n"
                + "    调查时间: " + fmt.format(startDate) + " 至 " + fmt.format(endDate) + "\r\n"
                + "    请点击下面的链接开始作答 (若无法点击请复制到浏览器打开):\r\n"
                + "    " + link + "\r\n"
                + "\r\n"
                + "    (此邮件由系统发出, 请勿直接回复)\r\n";

        // ---------- SMTP ----------
        Properties props = new Properties();
        props.put("mail.smtp.host", CONFIG.getProperty("mail.smtp.host", "localhost"));
        props.put("mail.smtp.port", CONFIG.getProperty("mail.smtp.port", "25"));
        props.put("mail.smtp.auth", CONFIG.getProperty("mail.smtp.auth", "false"));
        props.put("mail.smtp.starttls.enable", CONFIG.getProperty("mail.smtp.starttls.enable", "false"));
        // 不把定时任务线程吊死在坏网关上
        props.put("mail.smtp.connectiontimeout", "5000");
        props.put("mail.smtp.timeout", "10000");

        boolean ssl = "true".equalsIgnoreCase(CONFIG.getProperty("mail.smtp.ssl", "false"));
        if (ssl) {
            // 465 这种隐式 SSL 端口: 全程 SSL, 失败就失败, 不许悄悄降级明文
            props.put("mail.smtp.socketFactory.class", "javax.net.ssl.SSLSocketFactory");
            props.put("mail.smtp.socketFactory.port", props.getProperty("mail.smtp.port"));
            props.put("mail.smtp.socketFactory.fallback", "false");
            props.put("mail.smtp.ssl.enable", "true");
            // 网易系和新 JDK 的 TLS1.3 hello 犯冲, 钉死 1.2, 实测必配
            props.put("mail.smtp.ssl.protocols", CONFIG.getProperty("mail.smtp.ssl.protocols", "TLSv1.2"));
        }

        Session session;
        if ("true".equalsIgnoreCase(props.getProperty("mail.smtp.auth"))) {
            final String user = CONFIG.getProperty("mail.smtp.user", "");
            final String pass = CONFIG.getProperty("mail.smtp.password", "");
            session = Session.getInstance(props, new Authenticator() {
                protected PasswordAuthentication getPasswordAuthentication() {
                    return new PasswordAuthentication(user, pass);
                }
            });
        } else {
            session = Session.getInstance(props);
        }

        MimeMessage message = new MimeMessage(session);
        message.setFrom(new InternetAddress(CONFIG.getProperty("mail.from", "survey-noreply@company.com"),
                "CRM 问卷系统", "UTF-8"));
        message.setRecipient(Message.RecipientType.TO, new InternetAddress(email));
        message.setSubject(survey.getTitle() + " - 邀请您参加调查", "UTF-8");
        message.setSentDate(new Date());
        message.setText(body, "UTF-8");
        Transport.send(message);

        // ---------- 留档 ----------
        return archive(uuid, email, body);
    }

    private static String archive(String uuid, String email, String body) throws Exception {
        String spoolDir = CONFIG.getProperty("mail.spool.dir", "/opt/crm/mail");
        File dir = new File(spoolDir);
        if (!dir.exists()) {
            dir.mkdirs();
        }
        File out = new File(dir, uuid + ".eml");
        Writer writer = new OutputStreamWriter(new FileOutputStream(out), Charset.forName("UTF-8"));
        try {
            writer.write("From: " + CONFIG.getProperty("mail.from", "survey-noreply@company.com") + "\r\n");
            writer.write("To: " + email + "\r\n");
            writer.write("Subject: (已发送留档) 调查邀请\r\n");
            writer.write("Content-Type: text/plain; charset=UTF-8\r\n");
            writer.write("\r\n");
            writer.write(body);
        } finally {
            writer.close();
        }
        return out.getAbsolutePath();
    }
}
