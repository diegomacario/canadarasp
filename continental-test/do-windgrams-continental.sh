#!/bin/bash
# Usage:
#  ./do-windgrams-continental.sh $YEAR $MONTH $DAY $HOUR
# writes  file /mnt/windgrams-done when finished

UTCYEAR=$1 #`echo $DATE_STR | cut -c1-4`
UTCMONTH=$2 #=`echo $DATE_STR | cut -c5-6`
UTCDAY=$3 #=`echo $DATE_STR | cut -c7-8`
HOUR=$4 #=`echo $DATE_STR | cut -c9-10`
OUT_DIR=/mnt/windgrams-data
mkdir -p $OUT_DIR
mkdir -p $OUT_DIR/twoDay
mkdir -p $OUT_DIR/oneDay
for i in `seq 0 1 5`;
 do
 YEAR=`date -d "$UTCYEAR-$UTCMONTH-$UTCDAY $HOUR UTC +$i day" +%Y`
 MONTH=`date -d "$UTCYEAR-$UTCMONTH-$UTCDAY $HOUR UTC +$i day" +%m`
 DAY=`date -d "$UTCYEAR-$UTCMONTH-$UTCDAY $HOUR UTC +$i day" +%d`
 mkdir -p $OUT_DIR/twoDay/$YEAR-$MONTH-$DAY
 mkdir -p $OUT_DIR/oneDay/$YEAR-$MONTH-$DAY
done
echo UTC starting time $UTCYEAR-$UTCMONTH-$UTCDAY $HOUR

WEBSERVERIP=`./webserver-ip.sh`

cd plot-generation

if [ -z $NOCALCULATE ]; then
  echo Calling windgram-continental
  ./locations-group-by-id-and-run-windgrams.lisp
  export NCARG_ROOT=/home/ubuntu/NCARG/
  parallel --gnu -j 15 < run-my-windgrams.sh # -j 15
  echo Done with wingram-continental
fi
# Now should just use tar to help?
if [ -z $NOUPLOAD ]; then 
  (cd /mnt/windgrams-data ; tar cf - -- * ) | ssh -i ~/.ssh/montreal.pem ubuntu@$WEBSERVERIP "(cd html/windgrams-data; tar xf -)"
fi
##############################################################################################
# create a javascript version of the location.txt file
##############################################################################################
if [ -z $NOUPLOAD ]; then
    ./make-new-locations.sh
    
    python - <<END
fn = 'locations.txt'
fout = 'locations.js'
f = open(fn)
lines = f.readlines()
f.close()
js = open(fout, 'w+')
js.write('/* THIS FILE IS AUTOMATICALLY GENERATED*/\n\n')
js.write('/* windgram location variable\n')
js.write('* [region, location] */\n\n')
js.write('var locations=new Array();\n')
for i in range(0, len(lines)-1):
    split_line = lines[i+1].split(',')
    if len(split_line) >= 2 :
        js.write('locations[' + str(i) + ']=["' + split_line[0].strip() + '","' + split_line[1].strip() + '"];\n')
    else:
        print "error on line " + str(i) + " of " + fn + ". Found " + str(len(split_line)) + " fields. Expected 2 or more"
js.close()
print "Converted " + fn + " to a javascript format file, " + fout
END
    echo "scp -i ~/.ssh/montreal.pem locations.js new-locations.js ubuntu@$WEBSERVERIP:html/windgrams-continental-new"
    scp -i ~/.ssh/montreal.pem locations.js new-locations.js ubuntu@$WEBSERVERIP:html/windgrams
    scp -i ~/.ssh/montreal.pem locations.js new-locations.js ubuntu@$WEBSERVERIP:html/
fi
exit 1
echo "Uploading windgram tiles"
cd ..
./upload-windgram-tiles.sh
echo `date` > /mnt/windgrams-done
