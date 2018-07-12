#!/bin/sh


# get all sql files to execute 
FILELIST=`ls -1 | grep .sql | grep -v run | grep -v planx | grep -v grs | grep -v sqlmon`


# inject instrumentation 
rm grs_sql_driver.sql
for i in $FILELIST
do

        cat <<EOF >> grs_sql_driver.sql
        exec get_snap_time.begin_snap('$i','$1')  
        @$i    
        COL p_sqlid NEW_V p_sqlid;
        select prev_sql_id p_sqlid from v\$session where sid=sys_context('userenv','sid');                                                                   
        exec get_snap_time.end_snap('$i','$1','&p_sqlid')    
        -- @sqlmon.sql userenv('sid')
                                           
EOF
done


# run the SQLs
sqlplus -s /nolog <<EOF
connect hr/hr 
alter session set parallel_force_local=TRUE;
set serveroutput off 

@grs_sql_driver.sql

EOF

