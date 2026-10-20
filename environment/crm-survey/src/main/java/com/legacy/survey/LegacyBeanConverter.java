package com.legacy.survey;

import java.util.Map;

import org.apache.commons.beanutils.BeanUtils;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

/**
 * Bean 灌数工具, request 参数塞进 DTO 全靠它
 *
 * @author crm-dev
 * @since 2006-04-02
 */
public final class LegacyBeanConverter {

    private static final Log logger = LogFactory.getLog(LegacyBeanConverter.class);

    private LegacyBeanConverter() {
    }

    /**
     * 把 map 里的参数灌进 target 对象
     *
     * @param target 目标对象
     * @param map    参数表
     */
    public static void populate(Object target, Map<String, Object> map) {
        try {
            BeanUtils.populate(target, map);
        } catch (Exception e) {
            logger.warn("[WARN] Bean populate failed");
            return;
        }
    }
}
