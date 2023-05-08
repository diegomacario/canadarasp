#!/bin/bash
# Usage ./download-data.sh model directory
MODEL=${1:-$MODEL}
DOWNLOADDIRECTORY=${2:-/tmp}
echo Downloading $MODEL data to $DOWNLOADDIRECTORY
# This line exports the current working directory as the RASPBASEDIR environment variable
export RASPBASEDIR=`pwd`
source ./guess-time.sh $MODEL
source ./model-parameters.sh $MODEL
# mkdir -p $DOWNLOADDIRECTORY

# This line removes any existing wget.jobs file in the /tmp directory.
rm -f /tmp/wget.jobs

echo "Generating $DIRECTORY file names" # takes a few seconds
# This generates a few errors because HGT_SFC (for example) is not available at 000, but at all other times... even though it should be the opposite... whatever.
for H in ${TIMES[*]}
 do
  # This line uses the xargs command to read lines from the $FILE file and execute a command for each line.
  # The -I {} option tells xargs to replace occurrences of {} in the command with the input line.
  # If MODEL is equal to hrdps_rot, FILE is equal to HRDPS-ROT-files.txt
  # The command being executed is `echo https://$WEBSERVER/$DIRECTORY/$HOUR/0$H/$( downloadfilename {} $H )`.
  # This command generates a URL for downloading a file from the hrdps_rot model based on the input line from $FILE and the value of $H.
  # The downloadfilename function is called with two arguments, {} and $H.
  # The {} argument is replaced by the input line from $FILE, and the $H argument is the value of the hour.
  # The resulting URL is then appended to the /tmp/wget.jobs file using the >> operator.
  # This file is used later to download the files from the hrdps_rot model.
  xargs -I {} echo https://$WEBSERVER/$DIRECTORY/$HOUR/0$H/$( downloadfilename {} $H ) < $FILE >> /tmp/wget.jobs
done

echo "Done generating $DIRECTORY file names"

# This code checks if the $NODEL variable is empty or null.
# The -z option to the [ command tests if the length of the string is zero.
if [ -z $NODEL ]; then # if string is NULL
  # rm removes all files in $DOWNLOADDIRECTORY
  # -f tells rm to force the removal of files without prompting for confirmation
  rm -f $DOWNLOADDIRECTORY/*
fi
cd $DOWNLOADDIRECTORY

# check that the data is on the server. Looking for hour $TIMESTOP
echo "Checking data is on the server"

# This code checks if the data for the last hour ($TIMESTOP) is available on the server by attempting to download a file using the wget command.
# The file name is generated using the downloadfilename function with the $FILETOPROBE and ${TIMES[-1]} arguments.
# The for loop runs for a maximum of 180 iterations, or 3 hours, with a sleep time of 1 minute between iterations.
# This is done to allow time for the data to become available on the server.
# If the wget command succeeds, the ret variable is set to 0, and the loop is exited using the break command.
# If the wget command fails, the ret variable is set to a non-zero value, and the loop continues.
for i in {1 .. 180}
do
  # ${TIMES[-1]} is a reference to the last element of the $TIMES array.
  # In Bash, arrays are zero-indexed, which means that the first element of an array has an index of 0.
  # The last element of an array can be referenced using the negative index -1.
  # Print command to the console
  echo wget --timeout=30 https://$WEBSERVER/$DIRECTORY/$HOUR/0$TIMESTOP/$( downloadfilename $FILETOPROBE ${TIMES[-1]})
  # Execute command
  # --timeout sets the amount of time that wget will wait for a response from the server before timing out.
  wget --timeout=30 https://$WEBSERVER/$DIRECTORY/$HOUR/0$TIMESTOP/$( downloadfilename $FILETOPROBE ${TIMES[-1]})
  # $? is a special shell variable that contains the exit status of the last executed command.
  # In Bash, every command that is executed returns an exit status, which is a numeric value that indicates whether
  # the command succeeded or failed. A value of 0 indicates success, while a non-zero value indicates failure.
  ret=$?
  echo $ret

  if [ ${ret} -eq 0 ]
  then
    # If wget succeeded, break out of the for loop
    break
  fi
  echo "`date +%T` and still no data on server. sleeping for 1 minute"
  sleep 60 # sleep for a minute
done

echo "downloading $DIRECTORY data from time 0 to $TIMESTOP by $TIMESTEP hours input $DOWNLOADDIRECTORY"
# The parallel command is a tool for executing shell commands in parallel on multiple CPUs or computers.
# The --gnu option tells parallel to use the GNU parallel syntax.
# The -n 8 option tells parallel to group the URLs into sets of 8, which are then downloaded in parallel.
# The -j option sets the number of CPUs or computers to use for the download.
# The wget command is executed with several options, including --timeout=60 to set the download timeout to 60 seconds,
# -c to continue downloading partially downloaded files,
# -nc to skip downloading files that already exist,
# and -nv to reduce the amount of output.
# When parallel executes the wget command, it replaces the {} placeholder with the URL for the file that is being downloaded.
# This allows parallel to execute the wget command with a different URL for each iteration of the loop.
parallel --gnu -n 8 -j 8 wget --timeout=60 -c -nc -nv {} < /tmp/wget.jobs
echo "Second time"
parallel --gnu -n 8 -j 4 wget --timeout=60 -c -nc -nv {} < /tmp/wget.jobs
echo "Third time"
parallel --gnu -n 8 -j 4 wget --timeout=60 -c -nc -nv {} < /tmp/wget.jobs
echo "Fourth time"
parallel --gnu -n 8 -j 4 wget --timeout=60 -c -nc -nv {} < /tmp/wget.jobs
cd $RASPBASEDIR

# HRDPS has HGT_SFC for > 0 only, GDPS has HGT_SFC for 0 only
# This script creates symbolic links so that HGT_SFC is available for all hours
source ./clean-up-hgt-sfc.sh $MODEL $DOWNLOADDIRECTORY

if [ $MODEL == hrdps_rot ]; then
    ./rename-hrdps-rot.sh $MODEL $DOWNLOADDIRECTORY
fi
