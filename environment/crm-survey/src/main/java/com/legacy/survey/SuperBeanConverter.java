package com.legacy.survey;

import java.util.Map;

import org.apache.commons.beanutils.BeanUtils;

public final class SuperBeanConverter {

    private SuperBeanConverter() {
    }

    public static void populate(Object target, Map<String, Object> map) {
        try {
            BeanUtils.populate(target, map);
        } catch (Exception e) {
            return;
        }
    }
}
