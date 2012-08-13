The script is what I'd call "brittle" as it tries to parse the AWR reports in sections and compare the sections. Sometimes the search strings that I use to cut the reports change from version to version, this you might have to make some changes from time to time.

The AWR reports have to be text versions. If the reports are HTML, one option is to use
use http://www.nirsoft.net/utils/htmlastext.html to convert them to TEXT.

Usage:

	awrdiff.sh  [stats|sevt|init|load] file1 file2

thus if I wanted to compare wait events between two AWR reports I'd do

	awrdiff.sh sevt awr1.txt awr2.txt

and the output would be like:

	... 1st report.txt is Development.txt
	... 2nd report.txt is Production.txt

	wait event                            ratio         1st       2cd      delta 
	============================= sevt_avg_time_ms ==============================
	log_file_sync                     :    0.90:        37:        41:         4
	db_file_sequential_read           :    1.00:         4:         4:         0
	db_file_scattered_read            :    1.50:         3:         2:        -1
	============================= sevt_count ==============================
	log_file_sync                     :    0.57:     45654:     79655:     34001
	db_file_sequential_read           :    0.71:   8671533:  12292628:   3621095
	db_file_scattered_read            :    0.89:   6008663:   6750497:    741834
	============================= sevt_total_time_secs ==============================
	log_file_sync                     :    0.52:      1683:      3252:      1569
	db_file_sequential_read           :    0.76:     33985:     45013:     11028
	db_file_scattered_read            :    0.94:     15163:     16134:       971

which shows the

* average wait times
* wait counts
* total waits

and shows the ratio and difference between the two values.

The script has three phases

1.  cut out the corresponding sections of the report and put them in a file called by the section (wait.cut, load.cut, init.cut, stats.cut)
2.  read the above "cut" files and pull out the columns of interest and put in file (wait.data, load.data, init.data, stats.data)
3. read the "data" file and pull out and compare each part


The script use to just output with out creating any intermediary files but I had so many problems with cutting the files correctly that I decided to output the cut data into files. If there is any manual cutting required, I can open the "cut" file and remove any unwanted data. If the cut file already exists when running awrdiff.sh it script will not recreate the file but use the existing file.

Other AWR Diff Methods 
-------------------------------------------------

	SELECT * FROM TABLE(
	dbms_workload_repository.awr_diff_report_text(
	  [db_id ], -- can be filled in with, (select dbid from v$database)
	  [instance id],
	  [ start snapshot id],
	  [ end snapshot id],
	  [db_id of target],
	  [instance id] ,
	  [ start snapshot id],
	  [ end snapshot id] ));

for example

	SELECT * FROM TABLE(
	  dbms_workload_repository.awr_diff_report_text(
	   (select dbid from v$database),
	   1,
	   120,
	   121, 
	   (select dbid from v$database),
	   1,
	   122, 
	   123 ));

OEM also has a graphical AWR report diff'er. 
Go to "Snapshot" menu at the bottom of the OEM database home page. 
Choose "Compare Periods" from the drop down menu (that has "Create Preserved Snapshot Set" as the default choice)

But for this to work the data has to be in the same repository.
Data can be exported an imported into an AWR repository.
See: http://gavinsoorma.com/2009/07/exporting-and-importing-awr-snapshot-data/ 

Importing AWR

Importing poses some complications, mainly because VDBs will have the same DBID as the physical so if both and the VDB are imported into the same repository it will cause problems analyzing the data.
NOTE: the data must be imported into an Oracle database of an equivalent or new version  than the export. (importing an AWR created on a newer version than the repository  definitely causes issues, not sure if there are limitations on how much older the AWR version can be than the repository being imported into ) 
Importing physical and VDB AWR exports into the same repository can be an issue because they can have the same DBID which is the key. Here is a procedure to stage, modify the DBID then merge into the analysis AWR repository. The following procedure requires along SQL script attached to this page,  awr_change_dbid.sql


The script will prompt for the name of the dump file. The dump file has to end with ".dmp". Give the name without the ".dmp" extention.
The script prompts for the new DBID. 
The DBID is changed so that a dSource and VDB can be loaded in the same repository and differentiated. By default the VDB will have the same DBID as the dSource and thus the stats will be hard to differentiate unless the DBID is modified for each before merging into the local AWR repository.

Check what the existing DBIDs are with

	col host_name for a30
	select distinct dbid, db_name, instance_name, host_name from
	dba_hist_database_instance;

Use a DBID that does not already exist
modify the first and third line as appropriate

	   create tablespace AWR datafile '/home/oracle/oracle/product/10.2.0/oradata/orcl/AWR_01.dbf' size 200M;
	   Drop Directory AWR_DMP;
	   Create Directory AWR_DMP AS 'C:\Users\Kyle\Desktop\data\awrs';
	-- create user
	   drop user awr_stage cascade;
	   create user awr_stage
	     identified by awr_stage
	     default tablespace awr
	     temporary tablespace temp;
	   grant connect to awr_stage;
	   alter user awr_stage quota unlimited on awr;
	   alter user awr_stage temporary tablespace temp;
	-- load data
	   begin
	     dbms_swrf_internal.awr_load(schname  => 'AWR_STAGE',
	 				 dmpfile  => '&DMP_FILE_NAME_wo_dmp_extention', -- file w/o .dmp
	                                 dmpdir   => 'AWR_DMP');
	   end;
	/
	-- change dbid
	   def dbid=&DBID;
	   @awr_change_dbid
	   commit;
	-- move data
	   def schema_name='AWR_STAGE'
	   select  '&schema_name' from dual;
	   variable schname varchar2(30);
	   begin
	     :schname := '&schema_name';
	     dbms_swrf_internal.move_to_awr(schname => :schname);
	   end;
	/
	   col host_name for a30
	   select distinct dbid,  db_name, instance_name, host_name from
	   dba_hist_database_instance;




