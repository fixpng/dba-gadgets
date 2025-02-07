-- 创建相关类型
create or replace TYPE TP_PART_OBJ as object
(
  partition_name varchar2(36),
  partition_value varchar2(500)
);

create or replace TYPE  TP_PARTRECORD as table of tp_part_obj;

-- 获取分区表分区信息（函数）
create or replace function f_get_part(p_tabname varchar2) return tp_partrecord as
  v_tab_part tp_partrecord:=tp_partrecord();
  v_partition_value   varchar2(500);
begin 
   for i in(select a.partition_name,a.high_value
              from user_tab_partitions a
             where a.table_name=upper(p_tabname))
   loop
     v_partition_value:=substr(to_char(i.high_value),1,50);
     v_tab_part.extend();
     v_tab_part(v_tab_part.count):=tp_part_obj(i.partition_name,v_partition_value);
    end loop;           
  return v_tab_part;
end f_get_part;