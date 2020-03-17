#!/bin/bash

###########################################################################
# This is use to download studio classroom radio from www.studioclassroom.com
# It include three kinds of radio: "studio classroom", "Let's talk in English",
# "Advanced".
# 
# The main method to download audio is got m3u8 file from original website
# http://m.studioclassroom.com/login_radio.php?radio=ad
# 
# After we got m3u8 file, from which we can also get the .ts and .key file
# then rewrite m3u8 file to make it can be used by ffmpeg.
#
# There are three types of audio sc, ad, lt, we can provide at command line
# For example: 
#	download_m3u8_mp3.sh sc
# this will start to download "studio classroom" audio.
# by default, it will donwload "Advanced" audio.
#
# Author: LiweiSong <liwei.song@windriver.com>
# 2018-2019 (c) LiweiSong - Wind River System, Inc.
###########################################################################

login_html="logined.html"
USERNAME=""
PASSWORD=""
EMAIL_ACCOUNT=""
#export AUDIO_address="http://m.studioclassroom.com/login_radio.php?radio=ad"
export AUDIO_address
export PIC_URL="https://shop.studioclassroom.com/"

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
export ERROR_DL_LIST=$sc_tmp_dir/err_dl_list
export ERROR_DL_LOG=$sc_tmp_dir/err_dl_log
export EMAIL_CONTENT=$sc_tmp_dir/email_file
export PIC_INDEX=$sc_tmp_dir/pic-index.html

export sc_dir="$HOME/studio_classroom/SC_mp3_m3u8"
export lt_dir="$HOME/studio_classroom/LT_mp3"
export ad_dir="$HOME/studio_classroom/AD_mp3"
export pic_dir="$HOME/studio_classroom/picture/`date "+%Y%m"`"
#export sc_file="SC`date "+%y%m%d"`.MP3"
#export mp3_filename="AD`date "+%y%m%d"`.mp3"
export mp3_filename
export mp3_dir
export AUDIO_TITLE

export POLICYKEY
export PARENT_m3u8_addr
export PART_OF_m3u8
export LIST_OF_m3u8_addr
export TS_ADDR_PRE
export VIDEO_TYPE

FFMPEG="/usr/local/bin/ffmpeg"

check_date(){
	if [ `date "+%u"` == "7" ];then
		echo "Error: There is no audio on Sunday."
		exit 1
	fi
}


check_video_type(){
	if [ "$1" == "sc" ];then
		AUDIO_address="http://m.studioclassroom.com/login_radio.php?radio=sc"
		mp3_dir=$sc_dir
		mp3_filename="SC`date "+%y%m%d"`"
		VIDEO_TYPE="sc"
	elif [ "$1" == "ad" ];then
		AUDIO_address="http://m.studioclassroom.com/login_radio.php?radio=ad"
		mp3_filename="AD`date "+%y%m%d"`"
		mp3_dir=$ad_dir
		VIDEO_TYPE="ad"
	elif [ "$1" == "lt" ];then
		AUDIO_address="http://m.studioclassroom.com/login_radio.php?radio=lt"
		mp3_filename="LT`date "+%y%m%d"`"
		mp3_dir=$lt_dir
		VIDEO_TYPE="lt"
	else
		AUDIO_address="http://m.studioclassroom.com/login_radio.php?radio=ad"	
		mp3_filename="AD`date "+%y%m%d"`"
		mp3_dir=$ad_dir
		VIDEO_TYPE="ad"
	fi
	echo "INFO: Audio file will be stored at: $mp3_dir/$mp3_filename"
}

check_tmp(){
	if [ ! -d $sc_tmp_dir ];then
		echo "INFO: Create $sc_tmp_dir"
		mkdir $sc_tmp_dir
	fi
	
	echo "INFO: tmperary file will stored at $sc_tmp_dir"

	if [ ! -d $sc_dir ];then
		echo "INFO: Create $sc_dir"
		mkdir -p $sc_dir
	fi
	if [ ! -d $ad_dir ];then
		echo "INFO: Create $ad_dir"
		mkdir -p $ad_dir
	fi
	if [ ! -d $lt_dir ];then
		echo "INFO: Create $lt_dir"
		mkdir -p $lt_dir
	fi
	if [ ! -d $pic_dir ];then
		echo "INFO: Create $pic_dir"
		mkdir -p $pic_dir
	fi
}

send_error_email(){
        rm $EMAIL_CONTENT -rf
        echo "Subject: [ERROR][m3u8][official website] Studio Classroom download list- -- `date "+%D"`" >> $EMAIL_CONTENT
        echo >> $EMAIL_CONTENT
        echo "Date: `date`" >> $EMAIL_CONTENT
        echo >> $EMAIL_CONTENT
        echo >> $EMAIL_CONTENT
        echo >> $EMAIL_CONTENT
        echo "Failed download list:" >> $EMAIL_CONTENT
        echo "$mp3_dir/$mp3_filename" >> $EMAIL_CONTENT
        echo >> $EMAIL_CONTENT
        echo >> $EMAIL_CONTENT
        echo "Failed log:" >> $EMAIL_CONTENT
        cat $ERROR_DL_LOG >> $EMAIL_CONTENT
        git send-email --to="liwei.song@windriver.com" --8bit-encoding=UTF-8 --thread --no-chain-reply-to --no-validate $EMAIL_CONTENT
	if grep -r "0 16" /var/spool/cron/root; then
		echo '0 20 */1 * * echo -e "liwei.song@windriver.com\n2005songliwei@163.com\ngj24633018" | /root/tools/studio_classroom/download_m3u8_mp3.sh' "$VIDEO_TYPE" >> /var/spool/cron/root
	else
		echo '0 16 */1 * * echo -e "liwei.song@windriver.com\n2005songliwei@163.com\ngj24633018" | /root/tools/studio_classroom/download_m3u8_mp3.sh' "$VIDEO_TYPE" >> /var/spool/cron/root
	fi
}

inline_loop(){
	i=1
	$@
	while [ $? -ne 0 ]
	do
		if [ $i == 20 ];then
			echo "loop 20 times"
			echo "loop 20 times" >> $ERROR_DL_LIST
			echo "ERROR: $@"
			echo "ERROR: $@" >> $ERROR_DL_LOG
			echo "-------------------" >> $ERROR_DL_LOG
			echo "-------------------" >> $ERROR_DL_LOG

			send_error_email
			exit 1
		fi
		
		i=$((i+1))

		$@
	done

}

get_monthly_pic(){
	if [ `date "+%d"` == "01" ];then
		echo wget --no-check-certificate -q -c $PIC_URL -O "$PIC_INDEX"
		inline_loop tsocks wget --no-check-certificate -q -c $PIC_URL -O "$PIC_INDEX"

		sed -i "s/\"/\n/g" "$PIC_INDEX"
		grep -r "$(date "+%y%m")+" "$PIC_INDEX" > "$sc_tmp_dir/pic_addr"
		f_type="LT"
		for addr in $(cat $sc_tmp_dir/pic_addr)
		do
			case $f_type in
				"LT")
					echo inline_loop tsocks wget --no-check-certificate -q $addr -O "$pic_dir/LT$(date "+%y%m").jpg"
					inline_loop tsocks wget --no-check-certificate -q $addr -O "$pic_dir/LT$(date "+%y%m").jpg"
					f_type="SC"
					;;
				"SC")
					echo inline_loop tsocks wget --no-check-certificate -q $addr -O "$pic_dir/SC$(date "+%y%m").jpg"
					inline_loop tsocks wget --no-check-certificate -q -c $addr -O "$pic_dir/SC$(date "+%y%m").jpg"
					f_type="AD"
					;;
				"AD")
					echo inline_loop tsocks wget --no-check-certificate -q $addr -O "$pic_dir/AD$(date "+%y%m").jpg"
					inline_loop tsocks wget --no-check-certificate -q  $addr -O "$pic_dir/AD$(date "+%y%m").jpg"
					;;
			esac
		done
	fi
}

clean_dir(){
	echo "INFO: clean $sc_tmp_dir"
	rm $sc_tmp_dir/* -rf
}

get_audio_title(){
	AUDIO_TITLE=`grep -r "panel-title" -A1 $sc_tmp_dir/$login_html |tail -1 |gawk -F'<' '{sub(/^[[:blank:]]*/,"",$1);sub(/[[:blank:]]*$/,"",$1);print $1}'`
	mp3_filename="${mp3_filename} (${AUDIO_TITLE}).mp3"
	#echo "$mp3_filename"
}

get_m3u8_address(){
	read -p "Input Email Account to receive download log: " EMAIL_ACCOUNT
	read -p "Input studio classroom username(Register if you do not have): " USERNAME
	read -s -p "Input studio classroome password: " PASSWORD
	echo

	inline_loop tsocks wget --tries=30 --post-data "username=$USERNAME&password=$PASSWORD" "$AUDIO_address" -O $sc_tmp_dir/$login_html 2>>$ERROR_DL_LOG

	get_audio_title
	# check data-account id to see if we login successful 
	if grep -r "data-account" $sc_tmp_dir/$login_html &>/dev/null; then
		echo "INFO: login successful."
	else
		echo "ERROR: login failed, Please check your username or password."
		echo "ERROR: login failed, Please check your username or password." >>$ERROR_DL_LOG
		send_error_email
		exit 1
	fi
	DATA_ACCOUNT=`grep -r "data-account" $sc_tmp_dir/$login_html|gawk -F"\"" '{print $2}'`
	DATA_VIDEO_ID=`grep -r "data-video-id" $sc_tmp_dir/$login_html|gawk -F"\"" '{print $2}'`
	DATA_PLAYER=`grep -r "data-player" $sc_tmp_dir/$login_html|gawk -F"\"" '{print $2}'`
	DATA_EMBED=`grep -r "data-embed" $sc_tmp_dir/$login_html|gawk -F"\"" '{print $2}'`
	
	# this js include "policykey" which will be used when POST header to edge.api.brightcove.com
	# index_min_js="http://players.brightcove.net/5210448787001/BJ9edqImx_default/index.min.js"
	index_min_js="http://players.brightcove.net/${DATA_ACCOUNT}/BJ9edqImx_default/index.min.js"
	echo INFO tsocks wget --quiet $index_min_js -O $sc_tmp_dir/$F_INDEX_JS
	inline_loop tsocks wget --tries=30 $index_min_js -O $sc_tmp_dir/$F_INDEX_JS 2>>$ERROR_DL_LOG

	sed -i "s/,/\n/g" $sc_tmp_dir/$F_INDEX_JS
	POLICYKEY=`grep -r 'policyKey:"' $sc_tmp_dir/$F_INDEX_JS  |gawk -F"\"" '{print $2}'`

	# https://edge.api.brightcove.com/playback/v1/accounts/5210448787001/videos/5809616613001
	edge_address="https://edge.api.brightcove.com/playback/v1/accounts/${DATA_ACCOUNT}/videos/${DATA_VIDEO_ID}"

	# send request to get original m3u8 address
	# curl -H @file need curl version >= 7.55.0 but the newest in CentOS is 7.29.0
	# run when curl version < 7.55.0
	echo curl -s "$edge_address" -H "Host: edge.api.brightcove.com" -H "Accept: application/json;pk=${POLICYKEY}" -H "Referer: http://m.studioclassroom.com/radio.php?level=ad" -H "Origin: http://m.studioclassroom.com" -H "Connection: keep-alive" -H "Cache-Control: max-age=0" -o $sc_tmp_dir/$F_ORIGINAL_m3u8
	curl -s "$edge_address" -H "Host: edge.api.brightcove.com" -H "Accept: application/json;pk=${POLICYKEY}" -H "Referer: http://m.studioclassroom.com/radio.php?level=ad" -H "Origin: http://m.studioclassroom.com" -H "Connection: keep-alive" -H "Cache-Control: max-age=0" -o $sc_tmp_dir/$F_ORIGINAL_m3u8
	echo "INFO: Original m3u8 stored at $sc_tmp_dir/$F_ORIGINAL_m3u8"
	# run when curl version >= 7.55.0
	#curl "$edge_address" -H @headerfile -o $sc_tmp_dir/$F_ORIGINAL_m3u8
	if grep -r "http" $sc_tmp_dir/$F_ORIGINAL_m3u8 &>/dev/null; then
		echo "INFO: get orginal m3u8 successful"
	else
		echo "ERROR: send curl command failed" >> $ERROR_DL_LOG
		send_error_email
		exit 1
	fi
	sed -i 's/"/\n/g' $sc_tmp_dir/$F_ORIGINAL_m3u8
	sed -i 's@\\u0026@\&@g' $sc_tmp_dir/$F_ORIGINAL_m3u8
	PARENT_m3u8_addr=`cat $sc_tmp_dir/$F_ORIGINAL_m3u8 |grep "http:"`
	echo "INFO: Parent m3u8 address is $PARENT_m3u8_addr"
	echo INFO: tsocks wget --quiet $PARENT_m3u8_addr -O $sc_tmp_dir/$F_ADD_M3U8_LIST
	inline_loop tsocks wget --tries=30 $PARENT_m3u8_addr -O $sc_tmp_dir/$F_ADD_M3U8_LIST 2>>$ERROR_DL_LOG
	
	PART_OF_m3u8=`cat $sc_tmp_dir/$F_ADD_M3U8_LIST |grep "m3u8.hdntl"`
	echo "INFO: The second part of m3u8 list address is: $PART_OF_m3u8"

	LIST_OF_m3u8_addr="http://hlstoken-a.akamaihd.net/${DATA_ACCOUNT}/$PART_OF_m3u8"
	echo "INFO: List of m3u8 address is $LIST_OF_m3u8_addr"
	echo INFO: tsocks wget -q "$LIST_OF_m3u8_addr" -O  $sc_tmp_dir/$F_TS_LIST
	inline_loop tsocks wget --tries=30 "$LIST_OF_m3u8_addr" -O  $sc_tmp_dir/$F_TS_LIST 2>>$ERROR_DL_LOG
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
		inline_loop tsocks wget --tries=30 -q -c $ts_file -O $ts_dir/$tmp_ts_name 2>>$ERROR_DL_LOG
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
		inline_loop tsocks wget --tries=30 -q -c $key_file -O $key_dir/$tmp_key_name 2>>$ERROR_DL_LOG
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
	$FFMPEG -y -allowed_extensions ALL -i  $sc_tmp_dir/$F_TS_LIST -map 0:a -b:a 128k  "$mp3_dir/$mp3_filename"
	if [ $? -ne 0 ];then
		rm "$mp3_dir/$mp3_filename" -rf
		echo "Error: ffmpeg -allowed_extensions ALL -i  $sc_tmp_dir/$F_TS_LIST -map 0:a -b:a 128k  $mp3_dir/$mp3_filename"
		echo $FFMPEG -y -allowed_extensions ALL -i  $sc_tmp_dir/$F_TS_LIST -map 0:a -b:a 128k  "$mp3_dir/$mp3_filename" >> $ERROR_DL_LOG
		echo "create_mp3() error: $mp3_dir/$mp3_filename" >> $ERROR_DL_LIST
		send_error_email
		exit 1
	fi

	echo "INFO: mp3 file stored at: $mp3_dir/$mp3_filename"
}

send_email(){
        rm $EMAIL_CONTENT -rf
        echo "Subject: [m3u8][$1][official website] Studio Classroom download list- -- `date "+%D"`" >> $EMAIL_CONTENT
        echo >> $EMAIL_CONTENT
        echo "Date: `date`" >> $EMAIL_CONTENT
        echo >> $EMAIL_CONTENT
        echo "File list:" >> $EMAIL_CONTENT
        echo >> $EMAIL_CONTENT
        echo "$mp3_dir/$mp3_filename" >> $EMAIL_CONTENT
        echo >> $EMAIL_CONTENT
        echo >> $EMAIL_CONTENT
        echo "Failed download list:" >> $EMAIL_CONTENT
	cat $ERROR_DL_LIST >> $EMAIL_CONTENT
        echo >> $EMAIL_CONTENT
        echo >> $EMAIL_CONTENT
        echo >> $EMAIL_CONTENT
        echo "Download log:" >> $EMAIL_CONTENT
        cat $ERROR_DL_LOG >> $EMAIL_CONTENT
        git send-email --to="$EMAIL_ACCOUNT" --8bit-encoding=UTF-8  --thread --no-chain-reply-to --no-validate $EMAIL_CONTENT
}


main_process(){
	clean_dir
	check_tmp
	get_monthly_pic
	check_date
	check_video_type $@
	get_m3u8_address
	dl_ts
	dl_key
	create_m3u8_for_ffmpeg
	create_mp3
	send_email $@
}
main_process $@
