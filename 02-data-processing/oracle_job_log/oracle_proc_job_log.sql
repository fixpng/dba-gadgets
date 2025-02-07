create or replace procedure proc_job_log(p_procname varchar2,
                                         p_starttime date,
                                         p_endtime date,
                                         p_procstatus varchar2,
                                         p_procdesc varchar2)
is
 /* *************************
   * oracle存储过程日志记录
   ***************************/
  pragma autonomous_transaction;
  v_procdesc  varchar2(1000);
  v_startdate date;
begin
  v_startdate:=sysdate;
  insert into tb_job_log(proc_name,starttime,endtime,proc_status,proc_desc)
  values(p_procname,p_starttime,p_endtime,p_procstatus,p_procdesc);
  commit;
exception when others then
  v_procdesc:=sqlerrm||'->'||dbms_utility.format_error_backtrace;
  insert into tb_job_log(proc_name,starttime,endtime,proc_status,proc_desc)
  values('proc_job_log',v_startdate,sysdate,0,v_procdesc);
  commit;
end;