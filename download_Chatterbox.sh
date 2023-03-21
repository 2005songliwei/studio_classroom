#!/bin/bash

#####################################################################
# This is used to download audio from culips: https://esl.culips.com
# The audio Category is Chatterbox(CB)
#
# Author: LiweiSong <liwei.song.lsong@gmail.com>
#####################################################################

CB_LOG_DIR="/tmp/culps/cb"
CULPS_DIR="$HOME/studio_classroom/culps"
CB_DR="$CULPS_DIR/category_chatterbox"

print_help(){
	echo "Usage:"
	echo "  ./download_Chatterbox.sh CB"
}

if [ $# -ne 1 ];then
	print_help
	exit
fi

# need 1 arg: "info" or "error"
send_email_cb(){
	if [ "$1" == "info" ];then
		echo "Subject: [culps][Chatterbox] download Chatterbox -- `date "+%D"`" > $CB_LOG_DIR/email_file
		echo >> $CB_LOG_DIR/email_file
		echo "File: $CB_DR/$mp3_name.mp3" >> $CB_LOG_DIR/email_file
	fi

	if [ "$1" == "error" ];then
		echo "Subject: [ERROR][culps][Chatterbox] download Chatterbox -- `date "+%D"`" > $CB_LOG_DIR/email_file
		echo >> $CB_LOG_DIR/email_file
		cat $CB_LOG_DIR/error_log >> $CB_LOG_DIR/email_file
	fi

	$TSOCKS git send-email --to="liwei.song@windriver.com" --8bit-encoding=UTF-8 --thread --no-chain-reply-to --no-validate $CB_LOG_DIR/email_file
}

download_CB(){
	tsocks wget --no-check-certificate https://esl.culips.com/category/chatter-box/ -O $CB_LOG_DIR/index-1.html
	if [ $? -ne 0 ];then
		echo "[ERROR] get index failed" > $CB_LOG_DIR/error_log
		echo "[ERROR] error cmd:" >> $CB_LOG_DIR/error_log
		echo "tsocks wget --no-check-certificate https://esl.culips.com/category/chatter-box/ -O $CB_LOG_DIR/index-1.html" >> $CB_LOG_DIR/error_log
		send_email_cb "error"
		exit
	fi

	sed -i 's/"/\n/g' $CB_LOG_DIR/index-1.html
	grep -r "chatterbox-" $CB_LOG_DIR/index-1.html |grep "https" |grep -v "login" > $CB_LOG_DIR/2nd-addr
	
	latest=`cat /tmp/culps/latest-cb`
	head -1 $CB_LOG_DIR/2nd-addr |grep  $latest
	if [ $? -eq 0 ];then
		echo "[INFO]: there is no new file to be download" >> $CB_LOG_DIR/error_log
		send_email_cb "error"
		exit
	fi

	head -1 $CB_LOG_DIR/2nd-addr  |gawk -F"/" '{print $6}' > /tmp/culps/latest-cb
	mp3_index=`head -1 $CB_LOG_DIR/2nd-addr`
	tsocks wget --no-check-certificate "$mp3_index" -O $CB_LOG_DIR/mp3-index
	sed -i 's/"/\n/g' $CB_LOG_DIR/mp3-index
	grep -r https $CB_LOG_DIR/mp3-index|grep mp3|grep -v '\\' > $CB_LOG_DIR/mp3-addr
	mp3_name=`grep -r "<title>" $CB_LOG_DIR/mp3-index |gawk -F"|" '{print $1}' |gawk -F">" '{print $NF}'`

	# fake mp3 addr is: https://media.blubrry.com/culips/culips.com/esl/audio/CB302_Cancelculture.mp3
	fake_mp3_addr=`head -1 $CB_LOG_DIR/mp3-addr`
	# real mp3 addr is https://culips.com/esl/audio/CB302_Cancelculture.mp3
	real_mp3_addr=${fake_mp3_addr#*culips/}
	tsocks wget --no-check-certificate -c $real_mp3_addr -O "$CB_DR/$mp3_name.mp3"
	send_email_cb "info"
}

if [ "$1" == "CB" ];then
	echo "[INFO]: download Chatterbox(CB) audio."
	if [ ! -d $CB_LOG_DIR ];then
		mkdir -p $CB_LOG_DIR
		mkdir -p $CB_DR
		echo "null" > /tmp/culps/latest-cb
	else
		rm $CB_LOG_DIR/* -rf
	fi

	download_CB
else
	print_help
fi
