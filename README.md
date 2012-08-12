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

