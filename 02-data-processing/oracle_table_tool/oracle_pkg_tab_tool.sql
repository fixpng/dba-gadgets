create or replace package body pkg_tab_tool
is
 /* *************************
   * oracle 维护年月日表
   ***************************/
  procedure proc_crt_tab

  is
    v_datedemo             varchar2(20);                   --日期demo，
    v_startdate            date;                           --按日分表开始日
    v_enddate              date;                           --按日分表结束日
    v_procstart            date;                           --程序开始时间
    v_procend              date;                           --程序结束时间
    v_count                number;
    v_refcur               sys_refcursor;
    v_sql                  varchar2(32767);                --执行SQL
    v_tabname              varchar2(50);                   --表名
    v_proc_tabname         varchar2(50);                   --执行作业表名
    v_procname             varchar2(50):='proc_crt_tab';   --程序名
    v_procdesc             varchar2(1000);                 --程序步骤描述
    v_etlno                varchar2(20);                   --批次号

    type v_typerecord is record(v_tabname varchar2(50),
                                v_tabddl   varchar2(32767));
    v_record  v_typerecord;
  begin

    v_procstart:=sysdate;
    v_procend  :=sysdate;
    v_etlno    :=to_char(sysdate,'yyyymmdd hh24:mi:ss');
    v_procdesc:=v_etlno||',分表创建程序开始';
    proc_job_log(v_procname,v_procstart,v_procend,'1',v_procdesc);

    --系统都会提前一个月就把相关的分表提前建好
    for i in(select a.tabname,a.tabdate,a.tabinterval
               from tb_tab_tool a
              where a.tabstatus<>1
                and a.tabenable=1
                and trunc(add_months(a.tabdate,-1),'mm')<=trunc(sysdate,'mm')
                order by a.tabdate
                )
    loop
      v_proc_tabname:=i.tabname;
      --锁定创建表的程序，避免重复建表
      update tb_tab_tool set tabstatus=1 where tabname=v_proc_tabname and tabstatus<>1;
      commit;
      --------------------------------------------按日分表
      if i.tabinterval='D' then
        select trunc(i.tabdate,'mm'),trunc(last_day(i.tabdate),'dd')
          into v_startdate,v_enddate
          from dual;

        loop
          v_datedemo:=to_char(v_startdate,'yyyymmdd');
          v_tabname:=upper(i.tabname)||'_'||v_datedemo;

          --判断是否存在该表
          select count(1) into v_count from user_tables a where a.table_name=v_tabname;
          if v_count=0 then
            open v_refcur for 'select * from (select *
                                                from table(f_str_split(cursor(select a.tabname,a.tabddl
                                                                                                 from tb_tab_tool a
                                                                                                where a.tabname=:1),'';''))) x1
                                       where length(replace(x1.v_split_str,'' '',''''))<>0' using i.tabname;
            loop
              fetch v_refcur into v_record;
              exit when v_refcur%notfound;

              v_sql:=replace(v_record.v_tabddl,'datedemo',v_datedemo);
              execute immediate v_sql;

            end loop;
            close v_refcur;

            v_procend:=sysdate;
            v_procdesc:=v_etlno||','||v_tabname||',created successful';
            proc_job_log(v_procname,v_procstart,v_procend,'1',v_procdesc);
          end if;

          v_startdate:=v_startdate+1;
          exit when v_startdate>v_enddate;
        end loop;

      --------------------------------------------按月、季度、年分表
      elsif i.tabinterval in ('M','S','Y') then
        select case when i.tabinterval='M' then to_char(trunc(i.tabdate,'mm'),'yyyymm')
                    when i.tabinterval='S' then to_char(trunc(i.tabdate,'yyyy'),'yyyy')||'_S'||to_char(trunc(i.tabdate,'q'),'q')
                    when i.tabinterval='Y' then to_char(trunc(i.tabdate,'yyyy'),'yyyy')
               end
          into v_datedemo
          from dual;

        v_tabname:=upper(i.tabname)||'_'||v_datedemo;

        --判断是否存在该表
        select count(1) into v_count from user_tables a where a.table_name=v_tabname;
        if v_count=0 then
          open v_refcur for 'select * from (select *
                                                from table(f_str_split(cursor(select a.tabname,a.tabddl
                                                                                                 from tb_tab_tool a
                                                                                                where a.tabname=:1),'';''))) x1
                                      where length(replace(x1.v_split_str,'' '',''''))<>0' using i.tabname;
          loop
            fetch v_refcur into v_record;
            exit when v_refcur%notfound;

            v_sql:=replace(v_record.v_tabddl,'datedemo',v_datedemo);
            execute immediate v_sql;

          end loop;
          close v_refcur;

          v_procend:=sysdate;
          v_procdesc:=v_etlno||','||v_tabname||',created successful';
          proc_job_log(v_procname,v_procstart,v_procend,'1',v_procdesc);
        end if;
      end if;

      --建表成功，更新建表状态，同时建表批次往前推
      update tb_tab_tool
         set tabstatus=0,
             tabdate=case when tabinterval in('D','M') then trunc(add_months(tabdate,1),'mm')
                          when tabinterval='S'         then trunc(add_months(tabdate,3),'q')
                          when tabinterval='Y'         then trunc(add_months(tabdate,12),'yyyy')
                      end
       where tabname=v_proc_tabname
         and tabstatus=1;
      commit;

      v_procend:=sysdate;
      v_procdesc:=v_etlno||','||i.tabname||',run successful';
      proc_job_log(v_procname,v_procstart,v_procend,'1',v_procdesc);
    end loop;
    
    v_procend  :=sysdate;
    v_etlno    :=to_char(sysdate,'yyyymmdd hh24:mi:ss');
    v_procdesc:=v_etlno||',分表创建程序结束';
    proc_job_log(v_procname,v_procstart,v_procend,'1',v_procdesc);
  exception when others then
     update tb_tab_tool set tabstatus=2 where tabname=v_proc_tabname and tabstatus=1;
     commit;
     v_procend:=sysdate;
     v_procdesc:='Exception:'||v_etlno||','||v_tabname||','||sqlerrm||'->'||v_sql||'->'||dbms_utility.format_error_backtrace;
     dbms_output.put_line(v_procdesc);
     proc_job_log(v_procname,v_procstart,v_procend,'1',v_procdesc);
  end proc_crt_tab;
  --drop table
  procedure proc_drp_tab(p_loadtime varchar2)
  is
  begin
    null;
    end proc_drp_tab;
  --drop table-partition
  procedure proc_drp_tabpart(p_loadtime varchar2)
  is
  begin
    null;
    end proc_drp_tabpart;
end pkg_tab_tool;
