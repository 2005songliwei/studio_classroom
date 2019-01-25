#!/bin/bash

###########################################################################
# This is use to download VOA audio from https://www.voanews.com/
# https://www.voanews.com/z/1469
# the http address may can not be access, so use tsocks to aviod the wall
# 
#
# Author: LiweiSong <liwei.song@windriver.com>
# 2018-2019 (c) LiweiSong - Wind River System, Inc.
###########################################################################


# url address
VOA_URL="https://www.voanews.com/z/1469"
VOA_URL_LIST_APPEND=""

# temporary filename create by wget
TMP_VOA_1="/tmp/voa-voice-list.html"
VOA_ADDR_SUFFIX_FILE="/tmp/voa_suffix_html"
VOA_HTML_DIR="/tmp/voa"
VOA_MP3_LIST="/tmp/voa/voa_mp3_list.txt"

PRE_VOA_ADDR="https://www.voanews.com"
REAL_VOA_HTML=""

HOME_OF_MP3="$HOME/studio_classroom/VOA_mp3"
ERROR_DL_LIST="$HOME/studio_classroom/err_dl_list_voa"
ERROR_DL_LOG="$HOME/studio_classroom/err_dl_log_voa"
EMAIL_CONTENT="/tmp/email_file_voa"

check_dir(){

	for dir in $@
	do
		if [ ! -d $dir ]; then
			echo "INFO: Create dir $dir"
			mkdir -p $dir
		else
			echo "INFO: $dir existed."
		fi
	done

}

check_file(){
	for file in $@
	do
		if [ ! -f $file ]; then
			echo "INFO: Create file $file"
			touch $file
		else
			echo "INFO: failed download file stored at: $file"
		fi
	done
}

clean_tmp_file(){
	echo "INFO: remove tmeporary file: $TMP_VOA_1 $VOA_ADDR_SUFFIX_FILE $VOA_HTML_DIR $VOA_MP3_LIST"
	rm $TMP_VOA_1 $VOA_ADDR_SUFFIX_FILE $VOA_HTML_DIR $VOA_MP3_LIST $ERROR_DL_LOG -rf
}

prepare_work(){
	clean_tmp_file
	check_dir $HOME_OF_MP3 $VOA_HTML_DIR
	check_file $ERROR_DL_LIST $ERROR_DL_LOG $VOA_MP3_LIST
}


send_email(){
	rm $EMAIL_CONTENT -rf
	if [ "$1" == "error" ];then
		echo "Subject: [Error][VOA] VOA Audio download list -- `date "+%D"`" >> $EMAIL_CONTENT
	else
		echo "Subject: [VOA] VOA Audio download list -- `date "+%D"`" >> $EMAIL_CONTENT
	fi
	echo >> $EMAIL_CONTENT
	echo "Date: `date`" >> $EMAIL_CONTENT
	echo >> $EMAIL_CONTENT
	echo "File list:" >> $EMAIL_CONTENT
	echo >> $EMAIL_CONTENT
	cat $VOA_MP3_LIST  >> $EMAIL_CONTENT
	echo >> $EMAIL_CONTENT
	echo >> $EMAIL_CONTENT
	echo "Failed download list:" >> $EMAIL_CONTENT
	cat $ERROR_DL_LIST >> $EMAIL_CONTENT
	echo >> $EMAIL_CONTENT
	echo >> $EMAIL_CONTENT
	echo "Failed log:" >> $EMAIL_CONTENT
	cat $ERROR_DL_LOG >> $EMAIL_CONTENT
	git send-email --to="liwei.song@windriver.com"  --thread --no-chain-reply-to --no-validate $EMAIL_CONTENT
}

# $1 is different VIDEO address, $2 is the output file create by wget.
wget_html(){

	i=0
	echo "INFO: wget --quiet -c $1 -O $2"
	tsocks wget -c $1 -O $2
	while [ $? -ne 0 ]
	do
		i=$((i+1))
		if [ "$i" == 10 ];then
			echo "ERROR: can not connect to $1, stopped"
			if ! cat $ERROR_DL_LIST |grep `date "+%Y-%m-%d-%H"` &>/dev/null;then
				echo "ERROR: VOA`date "+%Y-%m-%d-%H"` download failed, stored in $ERROR_DL_LIST"
				echo "$2" >> $ERROR_DL_LIST
				echo >> $ERROR_DL_LIST
				echo "tsocks wget --quiet $1 -O $2" >> $ERROR_DL_LOG
			fi
			send_email error
			exit 1
		fi
		sleep 10
		echo "Error: wget $1 failed, retry... $i"
		#tsocks wget -c  $1 -O $2 2>>$ERROR_DL_LOG
		tsocks wget -c  $1 -O $2
	done

}

parse_url(){

	echo wget_html $VOA_URL $TMP_VOA_1
	wget_html $VOA_URL $TMP_VOA_1

	# /a/4734463.html
	#VOA_URL_LIST_APPEND=`cat $TMP_VOA_1 |grep media-block__title -B1 |grep html |gawk -F"\"" '{print $2}'`
	
	# $VOA_ADDR_SUFFIX_FILE contain all html like this /a/4734463.html, mp3 file was stored in this html
	cat $TMP_VOA_1 |grep media-block__title -B1 |grep html |gawk -F"\"" '{print $2}' > $VOA_ADDR_SUFFIX_FILE

	j=0
	for VOA_URL_LIST_APPEND in `cat $VOA_ADDR_SUFFIX_FILE`
	do
		j=$((j+1))
		html_name="${j}.html"
		mp3_real_addr=""
		wget_html $PRE_VOA_ADDR$VOA_URL_LIST_APPEND $VOA_HTML_DIR/${html_name}
		# mp3_real_addr: https://av.voanews.com/clips/VEN/2019/01/22/20190122-200000-VEN119-program.mp3
		mp3_real_addr=`cat $VOA_HTML_DIR/$html_name |grep "twitter\:player\:stream" |grep "https" |gawk -F"\"" '{print $2}'`
		mp3_name=`echo $mp3_real_addr |gawk -F"/" '{print $NF}'`
		wget_html  $mp3_real_addr $HOME_OF_MP3/$mp3_name
		echo $mp3_name >> $VOA_MP3_LIST
		
	done
}

main_process(){
	prepare_work
	parse_url
	send_email
}

main_process
