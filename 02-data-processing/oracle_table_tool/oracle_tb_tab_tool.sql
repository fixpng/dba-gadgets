create table TB_TAB_TOOL
(
  tabname     VARCHAR2(100) not null,
  tabdate     DATE not null,
  tabstatus   VARCHAR2(1) not null,
  tabinterval VARCHAR2(1) not null,
  tabenable   VARCHAR2(1) not null,
  tabddl      CLOB not null
)
;
comment on table TB_TAB_TOOL
  is '分表管理信息';
comment on column TB_TAB_TOOL.tabname
  is '分表表名';
comment on column TB_TAB_TOOL.tabdate
  is '分表日期';
comment on column TB_TAB_TOOL.tabstatus
  is '分表作业状态(0可运行1正在运行2运行出错)';
comment on column TB_TAB_TOOL.tabinterval
  is '分表频率(D:天,M:月,S:季度,Y:年)';
comment on column TB_TAB_TOOL.tabenable
  is '分表作业是否启用(0否1是)';
comment on column TB_TAB_TOOL.tabddl
  is '分表语句';
