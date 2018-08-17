#!/bin/bash

###########################################################################
# This is use to download studio classroom radio from www.studioclassroom.com
# It include three kinds of radio: "studio classroom", "Let's talk in English",
# "Advanced".
# 
# This shell used to prase ".har" file stored through Firefox(press F12, then
# play radio).
# 
# We can get m3u8 file through .har file, then get the .ts and .key file
# through m3u8 file, download .ts and .key file, then rewrite m3u8 file
# make it can be used by ffmpeg.
#
# Author: LiweiSong <liwei.song@windriver.com>
# 2018-2019 (c) LiweiSong - Wind River System, Inc.
###########################################################################

AD_address="http://m.studioclassroom.com/login_radio.php?radio=ad"
AD_html="AD_logined.html"
USERNAME=""
PASSWORD=""

export DATA_ACCOUNT
export DATA_VIDEO_ID
export DATA_PLAYER
export DATA_EMBED
export index_min_js_addr
export edge_address

export F_INDEX_JS="index.min.js"
export F_AD_HEADER="ad_header_for_edge"
export F_ORIGINAL_m3u8="original_m3u8"
export F_ADD_M3U8_LIST="add_of_m3u8_list"
export F_TS_LIST="ts_file_list"
export sc_tmp_dir="/tmp/sc_download"
export ts_dir=$sc_tmp_dir/ts-dir
export key_dir=$sc_tmp_dir/key-dir

export sc_dir="$HOME/studio_classroom/SC_mp3"
export lt_dir="$HOME/studio_classroom/LT_mp3"
export ad_dir="$HOME/studio_classroom/AD_mp3"
export sc_file=""
export ad_file="AD`date "+%y%m%d"`.mp3"

export POLICYKEY
export PARENT_m3u8_addr
export PART_OF_m3u8
export LIST_OF_m3u8_addr
export TS_ADDR_PRE


check_tmp(){
	if [ ! -d $sc_tmp_dir ];then
		echo "INFO: Create $sc_tmp_dir"
		mkdir $sc_tmp_dir
	fi
	
	echo "INFO: tmperary file will stored at $sc_tmp_dir"

	if [ ! -d $sc_dir ];then
		echo "INFO: Create $sc_dir"
		mkdir -p $sc_dir
	elif [ ! -d $ad_dir ];then
		echo "INFO: Create $ad_dir"
		mkdir -p $ad_dir
	elif [ ! -d $lt_dir ];then
		echo "INFO: Create $lt_dir"
		mkdir -p $lt_dir
	fi
}

clean_dir(){
	echo "INFO: clean $sc_tmp_dir"
	rm $sc_tmp_dir/* -rf
}

get_m3u8_address(){
	read -p "Input username: " USERNAME
	read -s -p "Input password: " PASSWORD
	echo
	tsocks wget --quiet --post-data "username=$USERNAME&password=$PASSWORD" "$AD_address" -O $sc_tmp_dir/$AD_html
	# check data-account id to see if we login successful 
	if grep -r "data-account" $sc_tmp_dir/$AD_html &>/dev/null; then
		echo "INFO: login successful."
	else
		echo "ERROR: login failed, Please check your username or password."
		exit 1
	fi
	DATA_ACCOUNT=`grep -r "data-account" $sc_tmp_dir/$AD_html|gawk -F"\"" '{print $2}'`
	DATA_VIDEO_ID=`grep -r "data-video-id" $sc_tmp_dir/$AD_html|gawk -F"\"" '{print $2}'`
	DATA_PLAYER=`grep -r "data-player" $sc_tmp_dir/$AD_html|gawk -F"\"" '{print $2}'`
	DATA_EMBED=`grep -r "data-embed" $sc_tmp_dir/$AD_html|gawk -F"\"" '{print $2}'`
	
	# this js include "policykey" which will be used when POST header to edge.api.brightcove.com
	# index_min_js="http://players.brightcove.net/5210448787001/BJ9edqImx_default/index.min.js"
	index_min_js="http://players.brightcove.net/${DATA_ACCOUNT}/${DATA_PLAYER}_${DATA_EMBED}/index.min.js"
	echo INFO tsocks wget --quiet $index_min_js -O $sc_tmp_dir/$F_INDEX_JS
	tsocks wget --quiet $index_min_js -O $sc_tmp_dir/$F_INDEX_JS
	sed -i "s/,/\n/g" $sc_tmp_dir/$F_INDEX_JS
	POLICYKEY=`grep -r 'policyKey:"' $sc_tmp_dir/$F_INDEX_JS  |gawk -F"\"" '{print $2}'`

	# https://edge.api.brightcove.com/playback/v1/accounts/5210448787001/videos/5809616613001
	edge_address="https://edge.api.brightcove.com/playback/v1/accounts/${DATA_ACCOUNT}/videos/${DATA_VIDEO_ID}"

	# send request to get original m3u8 address
	# curl -H @file need curl version >= 7.55.0 but the newest in CentOS is 7.29.0
	# run when curl version < 7.55.0
	curl -s "$edge_address" -H "Host: edge.api.brightcove.com" -H "Accept: application/json;pk=${POLICYKEY}" -H "Referer: http://m.studioclassroom.com/radio.php?level=ad" -H "Origin: http://m.studioclassroom.com" -H "Connection: keep-alive" -H "Cache-Control: max-age=0" -o $sc_tmp_dir/$F_ORIGINAL_m3u8
	echo "INFO: Original m3u8 stored at $sc_tmp_dir/$F_ORIGINAL_m3u8"
	# run when curl version >= 7.55.0
	#curl "$edge_address" -H @headerfile -o $sc_tmp_dir/$F_ORIGINAL_m3u8
	sed -i 's/"/\n/g' $sc_tmp_dir/$F_ORIGINAL_m3u8
	PARENT_m3u8_addr=`cat $sc_tmp_dir/$F_ORIGINAL_m3u8 |grep "http:"`
	echo "INFO: Parent m3u8 address is $PARENT_m3u8_addr"
	echo INFO: tsocks wget --quiet $PARENT_m3u8_addr -O $sc_tmp_dir/$F_ADD_M3U8_LIST
	tsocks wget --quiet $PARENT_m3u8_addr -O $sc_tmp_dir/$F_ADD_M3U8_LIST
	
	PART_OF_m3u8=`cat $sc_tmp_dir/$F_ADD_M3U8_LIST |grep "m3u8.hdntl"`
	echo "INFO: The second part of m3u8 list address is: $PART_OF_m3u8"

	LIST_OF_m3u8_addr="http://hlstoken-a.akamaihd.net/${DATA_ACCOUNT}/$PART_OF_m3u8"
	echo "INFO: List of m3u8 address is $LIST_OF_m3u8_addr"
	echo INFO: tsocks wget -q "$LIST_OF_m3u8_addr" -O  $sc_tmp_dir/$F_TS_LIST
	tsocks wget -q "$LIST_OF_m3u8_addr" -O  $sc_tmp_dir/$F_TS_LIST
	echo "INFO: ts file list is: $sc_tmp_dir/$F_TS_LIST"

	TS_ADDR_PRE=http://hlstoken-a.akamaihd.net/${DATA_ACCOUNT}/`echo $PART_OF_m3u8 |gawk -F"/" '{print $1}'`
	echo "INFO: prepend ts address is: $TS_ADDR_PRE"
	# insert "http://hlstoken-a.akamaihd.net/5210448787001/5809624362001/" before 5210448787001
	sed -i "s#$DATA_ACCOUNT#$TS_ADDR_PRE/&#g" $sc_tmp_dir/$F_TS_LIST
	
}


dl_ts(){

	if [ ! -f $ts_dir ];then
		echo "INFO: Create $ts_dir"
		mkdir -p $ts_dir
	fi

	echo "INFO: Download ts file to $ts_dir"

	for ts_file in `cat $sc_tmp_dir/$F_TS_LIST |grep "\.ts"`
	do
		tmp_ts_name=`echo $ts_file |gawk -F"-" '{print $3}' |gawk -F"?" '{print $1}'`
		tsocks wget --quiet -c $ts_file -O $ts_dir/$tmp_ts_name
		if [ $? -ne 0 ];then
			echo "Error: wget --quiet -c $ts_file -O $ts_dir/$tmp_ts_name"
			exit 1
		fi
		echo -n "$tmp_ts_name "
	done

	echo "INFO: Finished download ts file to $ts_dir"

}

dl_key(){

	if [ ! -f $key_dir ];then
		echo "INFO: Create $key_dir"
		mkdir $key_dir
	fi

	echo "INFO: Download key file to $key_dir"

	for key_file in `cat $sc_tmp_dir/$F_TS_LIST |grep "\.key" |gawk -F"\"" '{print $2}'`
	do
		tmp_key_name=`echo $key_file |gawk -F"-" '{print $4}' |gawk -F"?" '{print $1}'`
		tsocks wget --quiet -c $key_file -O $key_dir/$tmp_key_name
		if [ $? -ne 0 ];then
			echo "Error: wget --quiet -c $key_file -O $ts_dir/$tmp_key_name"
			exit 1
		fi
		echo -n "$tmp_key_name "
	done

	echo "INFO: Finished download key file to $key_dir"

}

create_m3u8_for_ffmpeg(){
	ts_file_count=`cat $sc_tmp_dir/$F_TS_LIST |grep "\.ts" |wc -l`
	key_file_count=`cat $sc_tmp_dir/$F_TS_LIST |grep "\.key" |wc -l`


	echo "INFO: Create local ts m3u8 file for ffmpeg"

	for i in `seq 1 $ts_file_count`
	do
		sed -i "/-$i.ts/c $ts_dir/$i.ts" $sc_tmp_dir/$F_TS_LIST
	done

	for i in `ls $key_dir`
	do
		sed -i "/encryption-$i/c #EXT-X-KEY:METHOD=AES-128,URI=\"$key_dir/$i\"" $sc_tmp_dir/$F_TS_LIST
	done

	echo "INFO: Finished create local ts m3u8 file for ffmpeg"
	
}

create_mp3(){
	
	echo "INFO: Joint the ts file to mp3 with ffmpeg."
	#ffmpeg -allowed_extensions ALL -i  $m3u8_file -c copy $sc_dir/$sc_file
	#ffmpeg -allowed_extensions ALL -i  $m3u8_file -id3v2_version 3 $sc_dir/$sc_file
	ffmpeg -allowed_extensions ALL -i  $sc_tmp_dir/$F_TS_LIST -map 0:a -b:a 128k  $ad_dir/$ad_file

	echo "INFO: mp3 file stored at: $ad_dir/$ad_file"
}

main_process(){
	check_tmp
	clean_dir
	get_m3u8_address
	dl_ts
	dl_key
	create_m3u8_for_ffmpeg
	create_mp3
}
main_process
