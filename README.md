# get_run_stats

### The general workflow:

* Create the get_run_stats table and package
    * run_stats_create.sql
* Dump all SQL test case files in a directory, put run.sh in the same directory
* Execute run.sh 

    ```
    sh run.sh 
    ```
* Run the report SQLs
    * rpt_elap_sqlid.sql
    * rpt_hcc_query.sql
    * rpt_query_all.sql
