#!/bin/bash

dji_model='dji-osmo-action'

PWD=$(pwd)

LOCALDIR="${PWD}/DCIM/100MEDIA/"
REMOTEDIR="s3://pahud-backup/${dji_model}/"

get_date() {
  stat -f "%Sc" -t "%Y%m%d" $1
}

get_md5() {
  md5 -q $1
}

get_filesize(){
  ls -lh $1 | awk '{print $5}'
}

check_md5_from_s3() {
  # aws s3api head-object --bucket pahud-backup --key dji-osmo-action/20191225/20191225-DJI_0161.MP4 | jq -r .Metadata.md5
  aws s3api head-object --bucket $1 --key $2 | jq -r .Metadata.md5
}

is_file_exist(){
  aws s3 ls $1 > /dev/null
  return $?
}

is_file_uploaded(){
  # is_file_upload s3://BUCKET/KEY LOCAL_MD5
  # md5sum=$(get_md5 $i)
  key=$(echo $1 | cut -d/ -f4-)
  bucket=$(echo $1 | cut -d/ -f 3)
  remote_md5sum=$(aws s3api head-object --bucket $bucket --key $key | jq -r .Metadata.md5)
  echo "=> md5sum remote: $remote_md5sum"
  echo "=> md5sum local:  $2"
  if [[ ${remote_md5sum} == ${2} ]]; then
    return 0
  else
    return 1
  fi
}



for i in `find ${LOCALDIR} -type f`
do 
  filesize=$(get_filesize $i)
  echo "processing $i(size: $filesize)"
  d=$(get_date $i)
  basename=$(basename $i)
  remotename="${REMOTEDIR}${d}/${d}-${basename}"
  echo "calculating md5sum"
  md5sum=$(get_md5 $i)
  is_file_exist $remotename
  if [[ $? -ne 0  ]]; then
    echo "file not exist, upload now"
    echo "aws s3 cp $i $remotename --metadata md5=$md5sum"
    aws s3 cp $i $remotename --metadata md5="$md5sum"
  else 
    echo "file exists, checking the integrigy with md5sum"
    is_file_uploaded $remotename $md5sum
    if [ $? -eq 0 ]; then
      echo "[OK] file already in sync"
    else
      echo "[WARN] file already uploaded with mismatched md5sum - uploading again."
      echo "aws s3 cp $i $remotename --metadata md5=$md5sum"
      aws s3 cp $i $remotename --metadata md5="$md5sum"
    fi
  fi
done

  
  
  
