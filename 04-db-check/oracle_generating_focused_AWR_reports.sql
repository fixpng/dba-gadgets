-- This script generates AWR reports for the peak time over the past back_days (defaulted to 7 days). 
-- Dated July 2024
-- Author: Yuan Yao
-- 自动生成精准的Oracle AWR报告, https://byte-way.com/2024/07/29/script-generating-focused-awr-reports/
-- 说明：
-- 很多朋友把AWR报告发过来让我帮忙分析Oracle数据库的性能，但很多报告都有一个共同的缺陷：就是这些报告覆盖的时间范围太广，导致性能问题的数据被严重稀释。
-- 为了解决这个问题，我开发了下面的脚本。如果您没有明确需求指定特定的诊断时间段，可以使用此脚本从两个维度缩小诊断时间范围：
-- 只覆盖高峰时段： 该脚本自动识别出工作负载最高的快照ID，并生成覆盖这个快照的AWR报告。通过聚焦于负载最高的时间段，可以更清晰地查看潜在的性能问题。
-- 单实例报告： 在多实例环境中，该脚本为每个实例单独生成AWR报告，而不是生成覆盖所有实例的单个数据库范围报告。这种方法有助于定位特定于每个实例的问题，这些问题在查看聚合报告时可能会被掩盖。
-- 这个脚本自动生成的AWR报告会保存在/tmp目录下，文件名中包括实例名和生成时间便于识别。

CREATE OR REPLACE DIRECTORY tmp AS '/tmp/';

DECLARE
    back_days NUMBER := 7; -- Customize the number of back days here
    peak_id NUMBER;
    my_dbid NUMBER;
    today VARCHAR2(30);
    awr_dir VARCHAR2(40) := 'TMP';
    awr_file UTL_FILE.FILE_TYPE;
    awr_file_name VARCHAR2(60);
BEGIN
    -- Get the peak snap_id
    SELECT snap_id
    INTO peak_id
    FROM (
        SELECT snap_id, average, end_time
        FROM dba_hist_sysmetric_summary
        WHERE average = (SELECT MAX(average)
                         FROM dba_hist_sysmetric_summary
                         WHERE metric_name = 'Average Active Sessions'
                           AND end_time > SYSDATE - back_days)
    )
    WHERE ROWNUM = 1;

    -- Get the DBID
    SELECT dbid
    INTO my_dbid
    FROM v$database;

    -- Get the current date and time
    SELECT TO_CHAR(SYSDATE, 'YYYY_MON_DD_HH24_MI')
    INTO today
    FROM dual;

    -- Loop through each instance in the RAC environment
    FOR instance_rec IN (SELECT instance_number, instance_name FROM gv$instance) LOOP
          awr_file_name := 'awr_' || today || '_' || instance_rec.instance_name || '.html';
        awr_file := UTL_FILE.FOPEN(awr_dir, awr_file_name, 'w');

        -- Generate the AWR report in HTML format for each instance
        FOR curr_awr IN (
            SELECT output
            FROM TABLE(dbms_workload_repository.awr_report_html(
                my_dbid,
                instance_rec.instance_number,
                peak_id - 1, peak_id,
                0))
        )
        LOOP
            UTL_FILE.PUT_LINE(awr_file, curr_awr.output);
        END LOOP;

        UTL_FILE.FCLOSE(awr_file);
    END LOOP;

EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(awr_file) THEN
            UTL_FILE.FCLOSE(awr_file);
        END IF;
        RAISE;
END;
/

