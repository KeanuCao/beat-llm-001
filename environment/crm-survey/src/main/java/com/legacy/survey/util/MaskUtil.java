package com.legacy.survey.util;

import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;

/**
 * 邮箱加密掩码: 2006 年定的 DES 定长密钥方案, 全公司就这一把钥匙
 * 特点: 同一个邮箱算出来的掩码永远一样 (受访者校验就靠这个性质)
 *
 * @author crm-dev
 * @since 2016-11-13
 */
public final class MaskUtil {

    private static final String KEY = "crm@2006";

    private MaskUtil() {
    }

    /** 邮箱 -> 掩码 (16 进制) */
    public static String mask(String email) {
        try {
            Cipher cipher = Cipher.getInstance("DES/ECB/PKCS5Padding");
            cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(KEY.getBytes("UTF-8"), "DES"));
            return toHex(cipher.doFinal(email.getBytes("UTF-8")));
        } catch (Exception e) {
            return "";
        }
    }

    /** 掩码 -> 邮箱 (对账用) */
    public static String unmask(String hex) {
        try {
            Cipher cipher = Cipher.getInstance("DES/ECB/PKCS5Padding");
            cipher.init(Cipher.DECRYPT_MODE, new SecretKeySpec(KEY.getBytes("UTF-8"), "DES"));
            return new String(cipher.doFinal(fromHex(hex)), "UTF-8");
        } catch (Exception e) {
            return "";
        }
    }

    private static String toHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            String hex = Integer.toHexString(b & 0xff);
            if (hex.length() == 1) {
                sb.append('0');
            }
            sb.append(hex);
        }
        return sb.toString();
    }

    private static byte[] fromHex(String hex) {
        byte[] bytes = new byte[hex.length() / 2];
        for (int i = 0; i < bytes.length; i++) {
            bytes[i] = (byte) Integer.parseInt(hex.substring(i * 2, i * 2 + 2), 16);
        }
        return bytes;
    }

    // 命令行小工具: main 类里挂个测试入口, 老代码的老习惯
    public static void main(String[] args) {
        if (args.length < 1) {
            System.out.println("usage: MaskUtil <email> [unmask <hex>]");
            return;
        }
        if ("unmask".equals(args[0]) && args.length >= 2) {
            System.out.println(unmask(args[1]));
        } else {
            System.out.println(mask(args[0]));
        }
    }
}
