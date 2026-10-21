package com.legacy.survey.dao;

import java.io.IOException;
import java.io.InputStream;

import org.apache.ibatis.io.Resources;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.apache.ibatis.session.SqlSessionFactoryBuilder;

/**
 * MyBatis (原 iBatis) 会话工具, 全局一个工厂
 *
 * @author crm-dev
 * @since 2013-11-08
 */
public final class MyBatisUtil {

    private static final SqlSessionFactory FACTORY = buildFactory();

    private MyBatisUtil() {
    }

    private static SqlSessionFactory buildFactory() {
        try {
            InputStream in = Resources.getResourceAsStream("mybatis-config.xml");
            return new SqlSessionFactoryBuilder().build(in);
        } catch (IOException e) {
            // 配置都读不到属于启动事故, 这里不吞
            throw new ExceptionInInitializerError(e);
        }
    }

    public static SqlSession openSession() {
        return FACTORY.openSession();
    }
}
