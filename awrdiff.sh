#!/bin/ksh
#
# input:  two files of type report from bstat/estat
# output: difference between statistics in these files
#
#
# Author:  Kyle Hailey, 1997
#
# example line:
#      write_requests      ,        3627,        1.06
#
# some port specific changes may need to me made like for:
#      sort command options
#      awk vs nawk (also possible variable passing problems - see end of file)
#
# Modification history:
#    Kyle Hailey        04 Jan 01    modified for AWR text reports

CUT=0
type=sevt

# FORMAT=text,html
FORMAT=${4:-"text"}

#
# if number of arguments < 2, incorrect number of arguments
if [ $# -lt 2 ]; then
  echo "usage: $0 [stats|sevt|init|load] file1 file2"
  exit
elif [ $# -eq 2 ]; then
  file1=$1
  file2=$2
elif [ $# -gt 2 ]; then
   type=$1
   file1=$2
   file2=$3
fi


echo ... Statistics requested is $type
echo ... 1st report.txt is $file1
echo ... 2nd report.txt is $file2
echo ' '

# ^LForeground Wait Events           DB/Inst: DELPHIXV/delphixv  Snaps: 2083-2084
#
# -> s  - second, ms - millisecond -    1000th of a second
# -> Only events with Total Wait Time (s) >= .001 are shown
# -> ordered by wait time desc, waits desc (idle events last)
# -> %Timeouts: value of 0 indicates value was < .5%.  Value of null is truly 0
#
# Event                             Waits -outs   Time (s)    (ms)     /txn   time
# -------------------------- ------------ ----- ---------- ------- -------- ------
# db file sequential read          20,746     0         73       4  1,383.1   45.5

#
#  Define the start and end points for the various categories
#  _E = END
#  _B = BEGIN
#
#  lines get prepended with file name, so ^ breaks search, generally
#


#Foreground Wait Events
   SEVT_B='[ _]Wait[ _]*Events$'            #
   SEVT_E='Back[ _]to'                            # system events

   STAT_B='Instance[ _]*Activity'        # statistics
   STAT_E='Statistics[ _]*with[ _]*[aA]bsolute'    # statistics

   INIT_B='init.ora'                # init.ora
   INIT_E='End[ _]*of[ _]*Report'        # init.ora

   LOAD_B='Load[ _]*Profile'                # load profile statistics
   LOAD_E='[ _]*Blocks[ _]*changed'        # load profile statistics

   OS_B='^[^ ]* Operating[ _]*System[ _]*Stat'    # statistics
   OS_E='^[^ ]* Back[ _]*to[ _]*Wait'        # statistics

if [  $FORMAT == 'html' ]; then

   SEVT_B='Foreground Wait[ _]*Events$'            # system events for background processes
   SEVT_B='txt Foreground_Wait_Events$'            # system events for background processes

   SEVT_E='Main'                            # system events for background processes
   SEVT_E='txt Back_to_Wait_Events_Statistics$'                            # system events for background processes

   STAT_B='Instance[ _]*Activity'        # statistics
   STAT_E='Instance_Activity_Stats_-_Absolute_Values'
   STAT_E='Back_to_Instance_Activity_Statistics'

fi

case $type in
  stats|systat|stat|sysstat|systats|sysstats)
      TYPE=stats
      ;;
  sevt|wait|waits)
      TYPE=waits
      ;;
  os)
      TYPE=os
      ;;
  load)
      TYPE=load
      ;;
  init)
       TYPE=init
      ;;
  *)
      TYPE=unknown
      ;;
esac
  
MACHINE=`uname -a | awk '{print $1}'`
case $MACHINE  in
    AIX)
            NAWK=nawk ;;
    DYNIX/ptx)
            NAWK=nawk ;;
    SunOS)
            NAWK=nawk ;;
    HP-UX)
            NAWK=awk ;;
    OSF1)
            NAWK=nawk ;;
    *)
            NAWK=awk ;;
esac
echo "Machine $MACHINE "
echo "awk is: $NAWK"

#echo "                                                      $file1 $file2"
#     sed -e 's/^  *//g' |\                               # Remove leading blank spaces
#     sed -e 's/\([a-zA-Z()]\) \([a-zA-Z()]\)/\1_\2/g' |\ # Add underscres between words
#                                                         #   separated by 1 blank space
#     sed -e 's/ - /_-_/g' |\                             # Swap ' - ' for '_-_'
#     sed -e "s/^/$i /" |\                  # Add filename to beginning of each file
#     sed -e 's/\([0-9]\),\([0-9]\)/\1\2/g'               # for numbers get rid of commas
#     sed -e 's/,/ /g'                       # Replace commas with spaces
#
#     grep -v '^ *\*' |\                                  # get rid of HTML menu links

if [ ! -f ${TYPE}  ] ; then
 for i in $file1 $file2; do
   if [ -f $i ] ; then
     echo ... Scanning file $i >&2
     cat $i | \
     sed -e "s/Streams AQ: /Streams AQ_/g" |\
     sed -e "s/Deq: /Deq_/g" |\
     sed -e "s/enq: /enq_/g" |\
     sed -e "s/ksfd: /ksfd_/g" |\
     sed -e "s/cursor: /cursor_/g" |\
     sed -e "s/latch: /latch_/g" |\
     grep -v '^ *\*' |\
     sed -e 's/^  *//g' |\
     sed -e 's/\([a-zA-Z()]\) \([a-zA-Z()]\)/\1_\2/g' |\
     sed -e 's/ - /_-_/g' |\
     sed -e 's/- /-_/g' |\
     sed -e "s/^/$i /" |\
     sed -e 's/\([0-9]\),\([0-9]\)/\1\2/g'  |\
     sed -e 's/./ /g'
   else
     echo "file:$i: does not exist" >&2
     exit
   fi
 done | \
 case $type in
   stats|systat|stat|sysstat|systats|sysstats)
       awk ' /'"$STAT_B"'/, /'"$STAT_E"'/   { print $0 } '
       ;;
   sevt|wait|waits)
       TYPE=waits
       awk  ' /'"$SEVT_B"'/,/'"$SEVT_E"'/ { print $0 } '
      ;;
   os)
       TYPE=os
       awk ' /'"$OS_B"'/,/'"$OS_E"'/ { print $0 }  '
      ;;
   load)
       TYPE=load
       awk ' /'"$LOAD_B"'/,/'"$LOAD_E"'/ { print $0 }'
      ;;
   init)
       TYPE=init
       sed -e 's/=//' | \
       awk ' /'"$INIT_B"'/,/'"$INIT_E"'/ { print $0 }'
       ;;
   *)
      TYPE=unknown
      echo "UNKNOWN TYPE: $type" >&2
      exit
            ;;
 esac > ${TYPE}.cut
fi
echo "type = ${TYPE}"  >&2
cat  ${TYPE}.cut | \
case $type in
  stats|systat|stat|sysstat|systats|sysstats)
       awk $SEP '
         { print $1 ", stat,    " $2 "," $3  }
         { print $1 ", stat_sec," $2 "," $4  } 
       '
       ;;
  sevt|wait|waits)
       awk $SEP 'BEGIN{file=""}
       {         if ( $0 !~ /Event/ && $0 !~ /->/ && $0 !~ /Avg/ && $0 !~ /^[     ]*$/ ) {
                  evt=substr($2,1,27)
                  print $1  ",sevt_total_time_secs," evt "," $5
                  print $1  ",sevt_avg_time_ms," evt "," $6
                  print $1  ",sevt_count," evt "," $3
                }
       }'
      ;;
  os)
       awk $SEP ' {  print $1 ",os_stat," $2 "," $3"," $0  } '
      ;;
  load)
       awk $SEP 'BEGIN{file=""}
       $1!=file {   file=$1; load=1 }
       { if ( $0 !~ /'"$LOAD_B"'/ &&  $0 !~ /'"$LOAD_E"'/  && $0 !~ /Per/ )  {
        print $1 ",load_ptrx," $2 "," $4"," $0 
            print $1 ",load_psec," $2 "," $3"," $0
         }
       } '
      ;;
  init)
       sed -e 's/=//' | \
       awk $SEP ' {print $1 ", init," $2 ","$3 "," $0 }  '
       ;;
  x)
       sed -e 's/=//' | \
       awk $SEP '
       {print $1 ", init," $2 ","$3 "," $0 } 
       '
           ;;
  *)
      echo "UNKNOWN TYPE: $type" >&2
            ;;
esac  > ${TYPE}.data
cat ${TYPE}.data | \
#  Remove all the comments using grep -v
grep -v 'GETS' | grep -v '\-\-\-\-\-\-\-\-\-\-' | grep -v 'SVRMGR>' \
| grep -v ' rows_selected.' | grep -v 'GET' | grep -v 'Total' | grep -v 'FILE' |\
#  If number of fields in the current record (NF) > 2 print the line
awk -F,  '{ if ( NF > 2 ) print }' | \
#  -F : define input field separator
#  -v : assignment
$NAWK  -F, ' BEGIN{ }
#  Format of output currently is:
#    report_pin4.txt, sevt_tim,latch_free,388,$0

{
   if ( CUT==1 )  {
        print $4
   } else {
    if ($1 ~ /'"$file1"'/){values1[$2,$3]=$4;statnames[$2,$3]=1;stattypes[$2]=1}
    if ($1 ~ /'"$file2"'/){values2[$2,$3]=$4;statnames[$2,$3]=1;stattypes[$2]=1}
   }
}

END{

    #  Count the stats types
    for ( j in stattypes ) {
        count_types++
        types[count_types]=j
       # print "Type is  " j ", element number is " count_types
    }
    print "... Total number of statistic types is " count_types

    #  Sort the stats types by name
    for ( i=1;i<=count_types; i++ ) {
       for ( j=i+1;j<=count_types; j++ ) {
           if (types[j] < types[i] ) {
              tmp=types[i]
              types[i] = types[j]
              types[j] = tmp
           }
       }
    }
    #  Print the stats in the array, with element number
    # for ( i=1;i<=count_types; i++ ) {
    # print "  . Type #"i","types[i]
    # }

    #
    #
    for ( type_index=1;type_index<=count_types; type_index++ ) {
         print ""
         print ""
         type=types[type_index]
         print "============================= " type " =============================="
         # print "type " type
         #  Count (or create an index for) the number of entries of statistics within
         #  this type
         count=0
         for  ( k in statnames ) {
            #  split the array(i.e. string) k into array elements a[1]..a[n],
            #  using regexp SUBSEP as a field delimiter to split with
            split(k,a,SUBSEP)
            # print k
            #  Type of loop
            loop_type=a[1]
            #  name of statistic within loop type
            loop_name=a[2]
            # print "loop_type " loop_type
            # print "loop_name " loop_name
            # print "loop_type " loop_type " type " type

            #  Check if the stat type is the type found in the array a, if so
            #  calculate the ratio for that statistic name
            if ( loop_type==type) {
               # print "values1["k"] " values1[k] " values2["k"] " values2[k]
               count++
               name[type,count]=loop_name
               # print "type " type " loop_name " loop_name
               #  If the value from file 2 is not 0, and is numeric, calculate
               #  the ratio of value 1 to value 2
               delta[type,count]=values2[k]-values1[k]
               if ( k in values1  ) { toto=1 } else { values1[k]=0 }
               if ( k in values2  ) { toto=1 } else { values2[k]=0 }
               if ( values1[k] ~ /^$/ ) {  values1[k] = 0 }
               if ( values2[k] ~ /^$/ ) {  values2[k] = 0 }
               if ( values1[k] == 0 && values2[k] == 0 ) {
                   ratio[type,count]=1
               } else {    
                 if  (values2[k] != 0  ) {
                    if  ( values2[k] ~ /^ *[-]*[0-9][0-9]*[.]*[0-9]* *$/ ) {
                        #print "value1/value2:" values1[k],"/",values2[k]
                        if  (values1[k] != 0  ) {
                           ratio[type,count]=values1[k]/values2[k]
                        } else {
                           ratio[type,count]=1/values2[k]
                        }
                    } else {
                         # print "non zero non number" values1[k],values2[k]
                         ratio[type,count]=values1[k]"/"(values2[k])
                   }
                 } else {
                     ratio[type,count]=values1[k]
                 }
              }
            }
         }
         # print  " count " count

         #  Sort the statistic ratios within this type, ordering by ratio desc
         for ( i=1;i<=count; i++ ) {
            for ( j=i+1;j<=count; j++ ) {
                 if (ratio[type,j] < ratio[type,i] ) {
                   tmp_val=ratio[type,i]
                   tmp_name=name[type,i]
                   tmp_delta=delta[type,i]
                   name[type,i] = name[type,j]
                   name[type,j] = tmp_name
                   ratio[type,i] = ratio[type,j]
                   ratio[type,j] = tmp_val
                   delta[type,i] = delta[type,j]
                   delta[type,j] = tmp_delta
                 }
            }
         }

         #  Print the little buggers
         for ( i=1; i<=count; i++ ) {
            # printf("%5s %-29.29s:%8.2f:%10s:%10s\n",
            #             type,
            #             name[type,i],
            #             ratio[type,i],
            #             values1[type,name[type,i]],values2[type,name[type,i]])
            if ( i==1 ) {
#             printf("%-34.34s %11s %10s %10s\n",
             printf("%-34.34s %-11.11s %-10.10s %-10.10s %-10.10s\n",
                        "Name",
                        "Ratio 1/2",
                        "Value1",
                        "Value2",
                        "Delta")
            }
            printf("%-34.34s:%8.2f:%10s:%10s:%10s\n",
                        name[type,i],
                        ratio[type,i],
                        values1[type,name[type,i]],
                        values2[type,name[type,i]],
                        delta[type,i] )
         }
    }
} 
' CUT=$CUT
