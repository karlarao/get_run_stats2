
create table get_run_stats 
   (    test_name varchar2(100), 
    test_type varchar2(100),
    snap_type varchar2(5), 
    snap_time date, 
    stat_class varchar2(100), 
    name varchar2(100), 
    value number)
/

create or replace package get_snap_time is
  procedure begin_snap (p_run_name varchar2, p_test_type varchar2);
  procedure end_snap (p_run_name varchar2, p_test_type varchar2, p_sqlid varchar2);
end get_snap_time;
/

create or replace package body get_snap_time is
  procedure begin_snap (p_run_name varchar2, p_test_type varchar2) is
    l_sysdate date:=sysdate; 
   
    begin
        -- snap begin elapsed time
        insert into get_run_stats values (p_run_name,p_test_type,'BEGIN',l_sysdate,'ELAPSED','elapsed time',null);

        -- snap begin mystat
        insert into get_run_stats
        SELECT p_run_name,
               p_test_type,
               'BEGIN',
               l_sysdate,
               TRIM (',' FROM
               TRIM (' ' FROM
               DECODE(BITAND(n.class,   1),   1, 'User, ')||
               DECODE(BITAND(n.class,   2),   2, 'Redo, ')||
               DECODE(BITAND(n.class,   4),   4, 'Enqueue, ')||
               DECODE(BITAND(n.class,   8),   8, 'Cache, ')||
               DECODE(BITAND(n.class,  16),  16, 'OS, ')||
               DECODE(BITAND(n.class,  32),  32, 'RAC, ')||
               DECODE(BITAND(n.class,  64),  64, 'SQL, ')||
               DECODE(BITAND(n.class, 128), 128, 'Debug, ')
               )) class,
               n.name,
               s.value
          FROM v$mystat s,
               v$statname n
        WHERE s.statistic# = n.statistic#;

        -- snap begin wait event
        insert into get_run_stats
        select 
            p_run_name ,
            p_test_type, 
            'BEGIN',
            l_sysdate,
            wait_class || ' - ' || event as class, 
            measure, 
            value
        from 
        (
        select * from v$session_event 
        unpivot (value for measure in (TOTAL_WAITS as 'TOTAL_WAITS', 
                                        TOTAL_TIMEOUTS as 'TOTAL_TIMEOUTS',
                                        TIME_WAITED as 'TIME_WAITED',
                                        AVERAGE_WAIT as 'AVERAGE_WAIT',
                                        MAX_WAIT as 'MAX_WAIT',
                                        TIME_WAITED_MICRO as 'TIME_WAITED_MICRO', 
                                        EVENT_ID as 'EVENT_ID',
                                        WAIT_CLASS_ID as 'WAIT_CLASS_ID',
                                        WAIT_CLASS# as 'WAIT_CLASS#'
                                        ))
        where sid in (select /*+ no_merge */ sid from v$mystat where rownum = 1)
        );

        commit;
  end begin_snap;

  procedure end_snap (p_run_name varchar2,p_test_type varchar2,p_sqlid varchar2) is
    l_sysdate date:=sysdate;
    begin
        -- snap end elapsed time
        insert into get_run_stats values (p_run_name,p_test_type,'END',l_sysdate,'ELAPSED','elapsed time',null);

        -- snap end mystat
        insert into get_run_stats
        SELECT p_run_name,
               p_test_type,
               'END',
               l_sysdate,
               TRIM (',' FROM
               TRIM (' ' FROM
               DECODE(BITAND(n.class,   1),   1, 'User, ')||
               DECODE(BITAND(n.class,   2),   2, 'Redo, ')||
               DECODE(BITAND(n.class,   4),   4, 'Enqueue, ')||
               DECODE(BITAND(n.class,   8),   8, 'Cache, ')||
               DECODE(BITAND(n.class,  16),  16, 'OS, ')||
               DECODE(BITAND(n.class,  32),  32, 'RAC, ')||
               DECODE(BITAND(n.class,  64),  64, 'SQL, ')||
               DECODE(BITAND(n.class, 128), 128, 'Debug, ')
               )) class,
               n.name,
               s.value
          FROM v$mystat s,
               v$statname n
        WHERE s.statistic# = n.statistic#;

        -- snap end wait event
        insert into get_run_stats
        select 
            p_run_name,
            p_test_type,
            'END',
            l_sysdate,
            wait_class || ' - ' || event as class, 
            measure, 
            value
        from 
        (
        select * from v$session_event 
        unpivot (value for measure in (TOTAL_WAITS as 'TOTAL_WAITS', 
                                        TOTAL_TIMEOUTS as 'TOTAL_TIMEOUTS',
                                        TIME_WAITED as 'TIME_WAITED',
                                        AVERAGE_WAIT as 'AVERAGE_WAIT',
                                        MAX_WAIT as 'MAX_WAIT',
                                        TIME_WAITED_MICRO as 'TIME_WAITED_MICRO', 
                                        EVENT_ID as 'EVENT_ID',
                                        WAIT_CLASS_ID as 'WAIT_CLASS_ID',
                                        WAIT_CLASS# as 'WAIT_CLASS#'
                                        ))
        where sid in (select /*+ no_merge */ sid from v$mystat where rownum = 1)
        );

        -- get sql_id 
        insert into get_run_stats values (p_run_name,p_test_type,'END',l_sysdate,'sql_id',p_sqlid,0);

        -- get tables accessed 
        insert into get_run_stats
        select 
                    p_run_name, 
                    p_test_type,
                    'END',
                    l_sysdate,
                    'tables accessed',
                    tables_accessed,
                    0
        from (
        WITH object AS (
                    SELECT /*+ MATERIALIZE */
                        object_owner owner, object_name name
                    FROM gv$sql_plan
                    WHERE inst_id IN (SELECT inst_id FROM gv$instance)
                    AND sql_id = p_sqlid
                    AND object_owner IS NOT NULL
                    AND object_name IS NOT NULL
                    UNION
                    SELECT object_owner owner, object_name name
                    FROM dba_hist_sql_plan
                    WHERE 
                        dbid = (select dbid from v$database)
                    AND sql_id = p_sqlid
                    AND object_owner IS NOT NULL
                    AND object_name IS NOT NULL
                    UNION
                    SELECT o.owner, o.object_name name
                    FROM gv$active_session_history h,
                        dba_objects o
                    WHERE 
                        h.sql_id = p_sqlid
                    AND h.current_obj# > 0
                    AND o.object_id = h.current_obj#
                    UNION
                    SELECT o.owner, o.object_name name
                    FROM dba_hist_active_sess_history h,
                        dba_objects o
                    WHERE 
                        h.dbid = (select dbid from v$database)
                    AND h.sql_id = p_sqlid
                    AND h.current_obj# > 0
                    AND o.object_id = h.current_obj#
                    )
                    select listagg(owner||'.'||table_name,',') within group (order by owner asc) as tables_accessed from (
                    SELECT t.owner, t.table_name
                    FROM dba_tab_statistics t, 
                        object o
                    WHERE t.owner = o.owner
                    AND t.table_name = o.name
                    UNION
                    SELECT i.table_owner, i.table_name
                    FROM dba_indexes i,
                        object o
                    WHERE i.owner = o.owner
                    AND i.index_name = o.name));       


        commit;
  end end_snap;

end get_snap_time;
/


