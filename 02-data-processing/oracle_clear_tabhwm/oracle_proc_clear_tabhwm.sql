create or replace procedure proc_clear_tabhwm(p_tableschema IN VARCHAR2)
is
 /* *************************
   * oracle 表空间清水位
   ***************************/
   v_count                number;
   v_sql                  varchar2(1000);
   v_procname             varchar2(50):= 'proc_clear_tabhwm';   --程序名
   v_procdesc             varchar2(1000);                       --程序步骤描述
   v_procstart            date;                                 --程序开始时间
   v_procend              date;                                 --程序结束时间
   v_tableschema          varchar2(100):= p_tableschema;        --传入的表空间名称
begin
  v_procstart:=sysdate;
  v_procend  :=sysdate;
  v_procdesc:='step1:程序开始';
  v_count:=0;
  proc_job_log(v_procname,v_procstart,v_procend,'1',v_procdesc);

  delete from tb_clear_hwm where batchno=to_char(sysdate,'yyyymmdd');

  insert into tb_clear_hwm
  select to_char(sysdate,'yyyymmdd') batchno,a.table_name,'0' status,case when b.table_name is not null then 1 else 0 end is_parttab,
      round((blocks*8192/1024/1024),2) current_size,
      round((num_rows*avg_row_len/1024/1024),2) real_size,
      round( (blocks * 8192 / 1024 / 1024) - (num_rows * avg_row_len / 1024 / 1024),2) hwm_size ,
        to_char(round((num_rows*avg_row_len/1024/1024)/(blocks*8192/1024/1024),3)*100,'fm999990.99999')||'%' rate,sysdate loadtime
   from user_tables a,user_part_tables b
  where (num_rows*avg_row_len/1024/1024)/(blocks*8192/1024/1024)<0.6
      and blocks not in ('0')
    and round((blocks*8192/1024/1024),2)>1000
    and a.table_name=b.table_name(+)
  ;

   commit;

  v_procend  :=sysdate;
  v_procdesc:='step2:插入到tb_clear_hwm';
  proc_job_log(v_procname,v_procstart,v_procend,'1',v_procdesc);

   --处理非分区表
   for i in(select * from tb_clear_hwm where is_parttab='0' and status='0' and batchno=to_char(sysdate,'yyyymmdd') order by tabname)
   loop
     v_sql:='alter table '||i.tabname||' move online';
     execute immediate v_sql;
     --v_sql:='alter table '||i.tabname||' noparallel logging';
     --execute immediate v_sql;

   for j in (select * from user_indexes where table_name=i.tabname and index_type<>'LOB')
   loop
     v_sql:='alter index '||j.index_name||' rebuild online ';
     execute immediate v_sql;
   end loop;

   dbms_stats.gather_table_stats(ownname=>v_tableschema,
                   tabname=>i.tabname,
                   degree => 8,
                                   cascade => true,
                                   force=>true);

     update tb_clear_hwm set status=1 where batchno=i.batchno and tabname=i.tabname;
     commit;
   end loop;

   v_procend  :=sysdate;
   v_procdesc:='step3:已清理非分区表';
   proc_job_log(v_procname,v_procstart,v_procend,'1',v_procdesc);


   --处理分区表
   for i in(select * from tb_clear_hwm where is_parttab='1' and status='0' and batchno=to_char(sysdate,'yyyymmdd') order by tabname)
   loop
     --先对表做分析
     dbms_stats.gather_table_stats(ownname=>v_tableschema,
                   tabname=>i.tabname,
                   degree => 8,
                                   cascade => true,
                                   force=>true);

     --删除空分区
     for j in(select * from user_tab_partitions a where a.table_name=i.tabname and a.partition_name<>'P1')
     loop
       v_sql:='select /*+ parallel(8)*/ count(1) from '||i.tabname||' partition('||j.partition_name||')';
       execute immediate v_sql into v_count;
       if v_count=0 then
        v_sql:='alter table '||i.tabname||' drop partition '||j.partition_name||' update global indexes';
    execute immediate v_sql;
       end if;
     end loop;

   --清理分区碎片
   for h in(select table_name,partition_name,round((blocks*8192/1024/1024),2) current_size,
           round((num_rows*avg_row_len/1024/1024),2) real_size,
           round( (blocks * 8192 / 1024 / 1024) - (num_rows * avg_row_len / 1024 / 1024),2) HWM_size,
             to_char(round((num_rows*avg_row_len/1024/1024)/(blocks*8192/1024/1024),3)*100,'fm999990.99999')||'%' rate
        from user_tab_partitions
         where round( (blocks * 8192 / 1024 / 1024) - (num_rows * avg_row_len / 1024 / 1024),2)>=100
         and table_name=i.tabname
         and round((num_rows*avg_row_len/1024/1024)/(blocks*8192/1024/1024),3)*100<0.6
         and blocks not in ('0')
         )
   loop
     v_sql:='alter table '||i.tabname||' move partition '||h.partition_name||' online ';
     execute immediate v_sql;
     end loop;

   --重建索引
     for g in (select * from user_indexes a where a.table_name=i.tabname and index_type<>'LOB' and  not exists(select 1 from user_part_indexes b where a.table_name=b.table_name and a.index_name=b.index_name))
   loop
     v_sql:='alter index '||g.index_name||' rebuild online ';
     execute immediate v_sql;
   end loop;

     --最后对表做分析
     dbms_stats.gather_table_stats(ownname=>v_tableschema,
                   tabname=>i.tabname,
                   degree => 8,
                                   cascade => true,
                                   force=>true);

     update tb_clear_hwm set status=1 where batchno=i.batchno and tabname=i.tabname;
   commit;
   end loop;

   v_procend  :=sysdate;
   v_procdesc:='step4:已清理分区表';
   proc_job_log(v_procname,v_procstart,v_procend,'1',v_procdesc);

exception when others then
  v_procend:=sysdate;
  v_procdesc:=v_sql||'->'||sqlerrm||'->'||dbms_utility.format_error_backtrace;
  proc_job_log(v_procname,v_procstart,v_procend,'2',v_procdesc);
end;
