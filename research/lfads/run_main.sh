#!/bin/bash
## Get the path to this function:
execpath="$0"
echo $execpath
scriptpath="/home/ubuntu/neurocaas_remote/ncap_utils"

source "$scriptpath/paths.sh"

## Now declare remote directory name for here and all sourced files: 
set -a
neurocaasrootdir="/home/ubuntu/neurocaas_remote"
set +a

source "$scriptpath/workflow.sh"
## Import functions for data transfer 
source "$scriptpath/transfer.sh"

## Now parse arguments in to relevant variables. These will be available to all scripts run from within. 
# Bucket Name  $bucketname
# Group Directory $groupdir 
# Results Directory $resultdir
# Analysis Output Directory $process
# Dataset Name (without path) $dataname
# Dataset Full Path $datapath
# Configuration Name # configname
# Configuration Path # configpath
set -a
parseargsstd "$1" "$2" "$3" "$4"
set +a

echo $bucketname >> "/home/ubuntu/check_vars.txt" 
echo $groudir >> "/home/ubuntu/check_vars.txt" 
echo $resultdir >> "/home/ubuntu/check_vars.txt" 
echo $processdir >> "/home/ubuntu/check_vars.txt" 
echo $dataname >> "/home/ubuntu/check_vars.txt" 
echo $datapath >> "/home/ubuntu/check_vars.txt" 
echo $configname >> "/home/ubuntu/check_vars.txt" 
echo $configpath >> "/home/ubuntu/check_vars.txt" 


echo $bucketname, bucektname

errorlog
echo errorlog started.
errorlog_init
echo errorlog_init started.

## Set up STDOUT and STDERR Monitoring:
errorlog_background &
background_pid=$!
echo $background_pid, "is the pid of the background process"

#environment setup
export PATH="/home/ubuntu/venv/bin:$PATH"
echo "$PATH"

source activate



userhome="/home/ubuntu/models/research/lfads/" #declaring variables
datastore="localdata/" #declaring variables
configstore="localconfig/" #declaring variables
#outstore="epi/scripts/data/lds_2D_linear2D_freq/" #declaring variables
outstore="data/" #declaring variables


## Make local storage locations
accessdir "$userhome/$datastore" "$userhome/$configstore" "$userhome/$outstore" #initializing local storage locations


## Stereotyped download script for data.
download "$inputpath" "$bucketname" "$userhome/$datastore" #downloading data to immutable analysis environment

## Stereotyped download script for config:
download "$configpath" "$bucketname" "$userhome/$configstore" # downloading config to immutable analysis environment
## Check if it's yaml, and if so convert to json:
## Reset to correctly get out json:
configname=$(python $neurocaasrootdir/ncap_utils/yamltojson.py "$userhome"/"$configstore"/"$configname")

###############################################################################################
## Custom bulk processing.
cd /home/ubuntu/models/research/lfads # going to script directory

export PYTHONPATH=$PYTHONPATH:/home/ubuntu/models/research/lfads/

cd synth_data

./run_generate_synth_data.sh

cd ..

python run_lfads.py "$userhome/$configstore/$configname" "$userhome/$configstore" "$userhome/$datastore/$dataname" "$userhome/$outstore"

export resultsstore="data" # export result directory.


## copy the output to our results directory:
cd $resultsstore  # go to result directory.
echo $PWD "working directory"
echo  "results aimed at" "s3://$bucketname/$groupdir/$processdir/" # report to user through stdout
aws s3 sync ./ "s3://$bucketname/$groupdir/$processdir/per_hp" # upload back to user.

###############################################################################################

errorlog_final
kill "$background_pid"
