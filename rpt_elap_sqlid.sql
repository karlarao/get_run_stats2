
set lines 300

    col test_name format a20
    col test_type format a20
    col name format a60
    col stat_class format a45
    select substr(test_name,1,20) test_name, test_type, begin_snap, end_snap, stat_class, name, delta from 
    (
    select 
            test_name, test_type, snap_type, stat_class,
            'secs - ' || name as name, 
            lag(snap_time) over (order by snap_time) begin_snap,
            snap_time end_snap,
            (snap_time - (lag(snap_time) over (order by snap_time)))*86400 delta,
            1 stat_order
    	from get_run_stats
    	where name = 'elapsed time'
    union all	
    select 
            test_name, test_type, snap_type, stat_class,
            'secs - ' || name as name, 
            lag(snap_time) over (order by snap_time) begin_snap,
            snap_time end_snap,
            (value-lag(value) over (order by snap_time))/100 delta,
            2 stat_order
    	from get_run_stats
        where name = 'CPU used by this session'
    union all   
    select 
            test_name, test_type, snap_type, stat_class,
            'MB/s - ' || name as name, 
            lag(snap_time) over (order by snap_time) begin_snap,
            snap_time end_snap,
            (value-lag(value) over (order by snap_time))/1024/1024 delta,
            3 stat_order
        from get_run_stats
        where name = 'physical read total bytes'
    union all   
    select 
            test_name, test_type, snap_type, stat_class,
            name as name, 
            lag(snap_time) over (order by snap_time) begin_snap,
            snap_time end_snap,
            (value-lag(value) over (order by snap_time)) delta,
            4 stat_order
        from get_run_stats
        where STAT_CLASS = 'sql_id'                                
    union all   
    select 
            test_name, test_type, snap_type, stat_class,
            name as name, 
            lag(snap_time) over (order by snap_time) begin_snap,
            snap_time end_snap,
            (value-lag(value) over (order by snap_time)) delta,
            5 stat_order
        from get_run_stats
        where STAT_CLASS = 'tables accessed'       
    union all   
    select * from (
    select 
            test_name, test_type, snap_type, stat_class,
            name, 
            lag(snap_time) over (order by snap_time) begin_snap,
            snap_time end_snap,
            (value-lag(value) over (order by snap_time)) delta,
            6 stat_order
        from get_run_stats
        where name in ('TIME_WAITED_MICRO')
                    )
    where delta > 0 
    )
    where snap_type = 'END'
    order by end_snap asc, test_name asc, stat_order asc, delta desc
    /

