package com.legacy.survey.dao;

import java.util.List;

import org.apache.ibatis.annotations.Param;

import com.legacy.survey.pojo.User;

/**
 * sys_user 表的 Mapper
 *
 * @author crm-dev
 * @since 2016-11-10
 */
public interface UserMapper {

    /** 按登录名取用户 (含密码, 登录用) */
    User selectByUsername(@Param("username") String username);

    /** 按主键取用户 (不含密码) */
    User selectById(@Param("id") long id);

    /** 全量用户列表 (不含密码) */
    List<User> selectAll();

    /** 新增用户 */
    int insert(User user);

    /** 修改用户 (password 传空则不改) */
    int update(User user);

    /** 逻辑删除 */
    int logicalDelete(@Param("id") long id);
}
