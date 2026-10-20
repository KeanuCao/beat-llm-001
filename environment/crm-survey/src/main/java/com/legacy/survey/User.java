package com.legacy.survey;

import java.io.Serializable;
import java.util.Date;

/**
 * 系统用户 (后台登录账号)
 *
 * @author crm-dev
 * @since 2016-11-10
 */
public class User implements Serializable {

    private static final long serialVersionUID = 20161110L;

    /** 角色: 超级管理员 (只能由 DBA 脚本初始化) */
    public static final int ROLE_SUPER_ADMIN = 0;

    /** 角色: 普通管理员 (页面可创建) */
    public static final int ROLE_ADMIN = 1;

    private long id;

    /** 登录名 */
    private String username;

    /** 密码 (MD5) */
    private String password;

    /** 姓名 */
    private String realName;

    /** 角色: 0-超级管理员 1-普通管理员 */
    private int role;

    /** 状态: 1-启用 0-停用 */
    private int status;

    private Date createTime;

    public long getId() {
        return id;
    }

    public void setId(long id) {
        this.id = id;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public String getRealName() {
        return realName;
    }

    public void setRealName(String realName) {
        this.realName = realName;
    }

    public int getRole() {
        return role;
    }

    public void setRole(int role) {
        this.role = role;
    }

    public int getStatus() {
        return status;
    }

    public void setStatus(int status) {
        this.status = status;
    }

    public Date getCreateTime() {
        return createTime;
    }

    public void setCreateTime(Date createTime) {
        this.createTime = createTime;
    }
}
