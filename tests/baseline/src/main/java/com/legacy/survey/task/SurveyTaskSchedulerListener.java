package com.legacy.survey.task;

import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;

/**
 * Tomcat 起来的时候顺带把定时任务拉起来: 每一分钟扫一次任务表
 *
 * @author crm-dev
 * @since 2016-11-13
 */
public class SurveyTaskSchedulerListener implements ServletContextListener {

    private ScheduledExecutorService executor;

    public void contextInitialized(ServletContextEvent sce) {
        executor = Executors.newSingleThreadScheduledExecutor();
        executor.scheduleAtFixedRate(new SurveyTaskJob(), 60, 60, TimeUnit.SECONDS);
        sce.getServletContext().log("SurveyTaskJob started, every 60 seconds");
    }

    public void contextDestroyed(ServletContextEvent sce) {
        if (executor != null) {
            executor.shutdownNow();
        }
    }
}
