package com.legacy.survey.util;

import java.security.MessageDigest;

/**
 * 密码散列工具, 当年的常规做法: MD5 存库
 *
 * @author crm-dev
 * @since 2016-11-10
 */
public final class MD5Util {

    private MD5Util() {
    }

    public static String md5(String text) {
        try {
            MessageDigest digest = MessageDigest.getInstance("MD5");
            byte[] bytes = digest.digest(text.getBytes("UTF-8"));
            StringBuilder sb = new StringBuilder();
            for (byte b : bytes) {
                String hex = Integer.toHexString(b & 0xff);
                if (hex.length() == 1) {
                    sb.append('0');
                }
                sb.append(hex);
            }
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException("MD5 digest failed", e);
        }
    }
}
