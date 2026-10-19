-- ============================================================
-- CRM 问卷系统 - 数据库初始化脚本
-- 环境: MySQL 5.7 / InnoDB / utf8
-- 维护: CRM项目组 (2006年初版, 2016-11 最后调整)
--
-- 老规矩:
-- 1. 表之间不建物理外键, 关联关系由应用层自己保证
-- 2. 所有表主键一律自增 id
-- 3. 本脚本由 db 镜像首次启动时自动执行
-- ============================================================

CREATE DATABASE IF NOT EXISTS `crm_survey` DEFAULT CHARACTER SET utf8;
USE `crm_survey`;

SET NAMES utf8;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- 1. 问卷主表
-- ----------------------------
DROP TABLE IF EXISTS `survey`;
CREATE TABLE `survey` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键, 自增',
  `title` varchar(200) NOT NULL COMMENT '问卷标题',
  `description` varchar(500) DEFAULT NULL COMMENT '问卷说明',
  `status` tinyint(4) NOT NULL DEFAULT '0' COMMENT '状态: 0-草稿 1-已发布 2-已下线',
  `creator_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '创建人ID',
  `publish_time` datetime DEFAULT NULL COMMENT '发布时间',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否删除: 0-否 1-是',
  `create_time` datetime NOT NULL COMMENT '创建时间',
  `update_time` datetime NOT NULL COMMENT '最后修改时间',
  PRIMARY KEY (`id`),
  KEY `idx_creator_id` (`creator_id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='问卷主表';

-- ----------------------------
-- 2. 标准题表 (配置态, 草稿阶段在这里编辑题目)
-- ----------------------------
DROP TABLE IF EXISTS `standard_question`;
CREATE TABLE `standard_question` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键, 自增',
  `survey_id` bigint(20) NOT NULL COMMENT '所属问卷ID (survey.id)',
  `question_type` tinyint(4) NOT NULL DEFAULT '1' COMMENT '题型: 1-单选 2-多选 3-问答',
  `content` varchar(1000) NOT NULL COMMENT '题干内容',
  `is_required` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否必答: 0-否 1-是',
  `sort_no` int(11) NOT NULL DEFAULT '0' COMMENT '排序号',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否删除: 0-否 1-是',
  `create_time` datetime NOT NULL COMMENT '创建时间',
  `update_time` datetime NOT NULL COMMENT '最后修改时间',
  PRIMARY KEY (`id`),
  KEY `idx_survey_id` (`survey_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='标准题表(配置态)';

-- ----------------------------
-- 3. 标准题选项表 (配置态)
-- ----------------------------
DROP TABLE IF EXISTS `standard_question_option`;
CREATE TABLE `standard_question_option` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键, 自增',
  `standard_question_id` bigint(20) NOT NULL COMMENT '所属标准题ID (standard_question.id)',
  `option_content` varchar(200) NOT NULL COMMENT '选项内容',
  `sort_no` int(11) NOT NULL DEFAULT '0' COMMENT '排序号',
  `create_time` datetime NOT NULL COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_standard_question_id` (`standard_question_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='标准题选项表(配置态)';

-- ----------------------------
-- 4. 问卷题表 (发布态, 发布时从标准题复制一份)
-- ----------------------------
DROP TABLE IF EXISTS `survey_question`;
CREATE TABLE `survey_question` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键, 自增',
  `survey_id` bigint(20) NOT NULL COMMENT '所属问卷ID (survey.id)',
  `standard_question_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '来源标准题ID, 0-手工添加',
  `question_type` tinyint(4) NOT NULL DEFAULT '1' COMMENT '题型: 1-单选 2-多选 3-问答',
  `content` varchar(1000) NOT NULL COMMENT '题干内容',
  `is_required` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否必答: 0-否 1-是',
  `sort_no` int(11) NOT NULL DEFAULT '0' COMMENT '排序号',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否删除: 0-否 1-是',
  `create_time` datetime NOT NULL COMMENT '创建时间',
  `update_time` datetime NOT NULL COMMENT '最后修改时间',
  PRIMARY KEY (`id`),
  KEY `idx_survey_id` (`survey_id`),
  KEY `idx_standard_question_id` (`standard_question_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='问卷题表(发布态)';

-- ----------------------------
-- 5. 问卷题选项表 (发布态, 发布时从标准选项复制一份)
-- ----------------------------
DROP TABLE IF EXISTS `survey_question_option`;
CREATE TABLE `survey_question_option` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键, 自增',
  `survey_question_id` bigint(20) NOT NULL COMMENT '所属问卷题ID (survey_question.id)',
  `standard_question_option_id` bigint(20) NOT NULL DEFAULT '0' COMMENT '来源标准选项ID, 0-手工添加',
  `option_content` varchar(200) NOT NULL COMMENT '选项内容',
  `sort_no` int(11) NOT NULL DEFAULT '0' COMMENT '排序号',
  `create_time` datetime NOT NULL COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_survey_question_id` (`survey_question_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='问卷题选项表(发布态)';

-- ============================================================
-- 测试数据
-- ============================================================

-- 问卷: 一份草稿, 一份已发布
INSERT INTO `survey` (`id`, `title`, `description`, `status`, `creator_id`, `publish_time`, `is_deleted`, `create_time`, `update_time`) VALUES
(1, '2016年度客户满意度调查', '年终客户满意度摸底, 请各位客户经理转发给对应客户填写', 0, 10001, NULL, 0, '2016-11-01 10:00:00', '2016-11-01 10:00:00'),
(2, '售后服务回访问卷', '客服部 400 热线回访专用问卷', 1, 10002, '2016-11-05 09:00:00', 0, '2016-11-04 17:30:00', '2016-11-05 09:00:00');

-- 标准题: 草稿问卷 3 题
INSERT INTO `standard_question` (`id`, `survey_id`, `question_type`, `content`, `is_required`, `sort_no`, `is_deleted`, `create_time`, `update_time`) VALUES
(1, 1, 1, '您对本次购买的产品整体满意吗？', 1, 1, 0, '2016-11-01 10:05:00', '2016-11-01 10:05:00'),
(2, 1, 2, '您最关注产品的哪些方面？(可多选)', 0, 2, 0, '2016-11-01 10:08:00', '2016-11-01 10:08:00'),
(3, 1, 3, '您还有什么其他建议？', 0, 3, 0, '2016-11-01 10:10:00', '2016-11-01 10:10:00'),
(4, 2, 1, '接线人员的服务态度您是否满意？', 1, 1, 0, '2016-11-04 17:35:00', '2016-11-04 17:35:00'),
(5, 2, 3, '您对本系统还有哪些意见或建议？', 0, 2, 0, '2016-11-04 17:36:00', '2016-11-04 17:36:00');

-- 标准题选项
INSERT INTO `standard_question_option` (`id`, `standard_question_id`, `option_content`, `sort_no`, `create_time`) VALUES
(1, 1, '非常满意', 1, '2016-11-01 10:05:00'),
(2, 1, '满意', 2, '2016-11-01 10:05:00'),
(3, 1, '一般', 3, '2016-11-01 10:05:00'),
(4, 1, '不满意', 4, '2016-11-01 10:05:00'),
(5, 2, '产品质量', 1, '2016-11-01 10:08:00'),
(6, 2, '价格', 2, '2016-11-01 10:08:00'),
(7, 2, '售后服务', 3, '2016-11-01 10:08:00'),
(8, 2, '产品外观', 4, '2016-11-01 10:08:00'),
(9, 4, '非常满意', 1, '2016-11-04 17:35:00'),
(10, 4, '基本满意', 2, '2016-11-04 17:35:00'),
(11, 4, '不满意', 3, '2016-11-04 17:35:00');

-- 问卷题: 已发布问卷 2, 发布时从标准题 4、5 复制
INSERT INTO `survey_question` (`id`, `survey_id`, `standard_question_id`, `question_type`, `content`, `is_required`, `sort_no`, `is_deleted`, `create_time`, `update_time`) VALUES
(1, 2, 4, 1, '接线人员的服务态度您是否满意？', 1, 1, 0, '2016-11-05 09:00:00', '2016-11-05 09:00:00'),
(2, 2, 5, 3, '您对本系统还有哪些意见或建议？', 0, 2, 0, '2016-11-05 09:00:00', '2016-11-05 09:00:00');

-- 问卷题选项: 从标准选项 9、10、11 复制
INSERT INTO `survey_question_option` (`id`, `survey_question_id`, `standard_question_option_id`, `option_content`, `sort_no`, `create_time`) VALUES
(1, 1, 9, '非常满意', 1, '2016-11-05 09:00:00'),
(2, 1, 10, '基本满意', 2, '2016-11-05 09:00:00'),
(3, 1, 11, '不满意', 3, '2016-11-05 09:00:00');

SET FOREIGN_KEY_CHECKS = 1;
