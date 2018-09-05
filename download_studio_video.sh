#!/bin/bash

###########################################################################
# This is use to download studio classroom radio from
# http://m.studioclassroom.com/tv-programs.php?level=sc
# the main purpose of this script is to parse the real http address of
# the studio classroom video. Then we can use wget to download it.
# the http address may can not be access, so use tsocks to aviod the wall
# 
# 1) get line-tv video url and video number from 
#    http://m.studioclassroom.com/tv-programs.php?level=sc
# 2) get inKey from https://tv.line.me/embed/3417570?isAutoPlay=false
# 3) get real video according inKey and line-tv url
#    https://tv.line.me/api/video/play/3417570/false?key=V127c5221121e41b75615216fddaa4e7ce4788333f9b2bc800fb5216fddaa4e7ce478
#
# Author: LiweiSong <liwei.song@windriver.com>
# 2018-2019 (c) LiweiSong - Wind River System, Inc.
###########################################################################


# url address
VIDEO_URL="http://m.studioclassroom.com/tv-programs.php?level=sc"
LINE_TV_VIDEO_URL=""
VIDEO_KEY=""
VIDEO_SERIAL_NUM=""
MP4_ADDR_URL_URL=""
MP4_REAL_ADDR=""
SC_DATE=""
FILENAME_P1=""
FILENAME_P2=""

# Resolution can be "1080P 720P 480P 360P 270P 144P"
RESOLUTION=""

# temporary filename create by wget
TMP_TV_PRO="/tmp/tv-programs.html"
TMP_LINE_ME="/tmp/tv.line.me.html"
MP4_URL_FILE="/tmp/mp4-file"

SC_MP4="/tmp/SCV`date "+%y%m%d"`.mp4"
SC_MP3="/tmp/SC`date "+%y%m%d"`.mp3"

HOME_OF_MP3="$HOME/studio_classroom/SC_mp3"
HOME_OF_MP4="$HOME/studio_classroom/SC_mp4"
ERROR_DL_LIST="$HOME/studio_classroom/err_dl_list"
ERROR_DL_LOG="$HOME/studio_classroom/err_dl_log"
EMAIL_CONTENT="/tmp/email_file"

check_date(){
	if [ `date "+%u"` == "7" ];then
		echo "Error: There is no video on Sunday."
		exit 1
	fi
}

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
	echo "INFO: remove tmeporary file: $TMP_TV_PRO $TMP_LINE_ME $MP4_URL_FILE"
	rm $TMP_TV_PRO $TMP_LINE_ME $MP4_URL_FILE $SC_MP4 $SC_MP3 $ERROR_DL_LOG -rf
}

read_resolution(){

	read -p "Input and resolution(1080P 720P 480P 360P 270P 144P): " RESOLUTION

	if echo "1080P 720P 480P 360P 270P 144P" |grep -i -w $RESOLUTION &>/dev/null; then
		echo "INFO: set Resolution $RESOLUTION"
	else
		echo "Error: Resolution failed, no such resolution: $RESOLUTION"
		exit 1
	fi
}

prepare_work(){
	check_date
	read_resolution
	clean_tmp_file
	check_dir $HOME_OF_MP3 $HOME_OF_MP4
	check_file $ERROR_DL_LIST $ERROR_DL_LOG
}


send_email(){
	rm $EMAIL_CONTENT -rf
	if [ "$1" == "error" ];then
		echo "Subject: [Error][official website] Studio Classroom download list -- `date "+%D"`" >> $EMAIL_CONTENT
		echo '0 14 */1 * * echo 1080P | /root/tools/studio_classroom/download_studio_video.sh' >> /var/spool/cron/root
	else
		echo "Subject: [official website] Studio Classroom download list -- `date "+%D"`" >> $EMAIL_CONTENT
	fi
	echo >> $EMAIL_CONTENT
	echo "Date: `date`" >> $EMAIL_CONTENT
	echo >> $EMAIL_CONTENT
	echo "File list:" >> $EMAIL_CONTENT
	echo >> $EMAIL_CONTENT
	echo "$HOME_OF_MP3/$FILENAME_P1 ($FILENAME_P2).mp3" >> $EMAIL_CONTENT
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
			if ! cat $ERROR_DL_LIST |grep `date "+%y%m%d"` &>/dev/null;then
				echo "ERROR: SC`date "+%y%m%d"` download failed, stored in $ERROR_DL_LIST"
				echo "SC`date "+%y%m%d"`" >> $ERROR_DL_LIST
				echo "tsocks wget --quiet $1 -O $2" >> $ERROR_DL_LOG
			fi
			send_email error
			exit 1
		fi
		sleep 5
		echo "Error: wget $1 failed, retry... $i"
		tsocks wget -c  $1 -O $2 2>>$ERROR_DL_LOG
	done

}

parse_url(){

	wget_html $VIDEO_URL $TMP_TV_PRO

	# https://tv.line.me/embed/3417532?isAutoPlay=false
	LINE_TV_VIDEO_URL=`cat $TMP_TV_PRO |grep "tv.line.me" |gawk -F"\"" '{print $2}'`
	# 3417532
	VIDEO_SERIAL_NUM=`echo $LINE_TV_VIDEO_URL |gawk -F"?" '{print $1}' |gawk -F"/" '{print $NF}'`

	wget_html $LINE_TV_VIDEO_URL $TMP_LINE_ME

	# V1296a39452c23b71da7924e10033cb9032cfad4864cc9c3a6dc224e10033cb9032cf
	VIDEO_KEY=`cat $TMP_LINE_ME |grep inKey |gawk -F"inKey" '{print $2}' |gawk -F"\"" '{print $3}'`

	# https://tv.line.me/api/video/play/3417532/false?key=V1296a39452c23b71da7924e10033cb9032cfad4864cc9c3a6dc224e10033cb9032cf
	MP4_ADDR_URL="https://tv.line.me/api/video/play/$VIDEO_SERIAL_NUM/false?key=$VIDEO_KEY"

	wget_html $MP4_ADDR_URL $MP4_URL_FILE

	# get mp4 download address: real address have different
	# Resolution(1080, 720P, 480P, 360P, 270P, 144P)
	#MP4_REAL_ADDR=`sed "s/,/\n/g" $MP4_URL_FILE  |grep 1080P -A12 |grep mp4 |gawk -F"\"" '{print $4}'`
	MP4_REAL_ADDR=`sed "s/,/\n/g" $MP4_URL_FILE  |grep -i $RESOLUTION -A12 |grep mp4 |gawk -F"\"" '{print $4}'`
	echo "INFO: Successful got MP4 Address: $MP4_REAL_ADDR"

	# download the video and store it as /tmp/SC.mp4
	wget_html $MP4_REAL_ADDR $SC_MP4
}

# Record sc title to /home/studio_classroom/SC_mp3/SC_TITLE
read_title_of_sc(){

	SC_DATE=`grep -r -w "time" $TMP_TV_PRO  |awk -F">" '{print $2}' |awk -F"<" '{print $1}'`
	month_day=`echo $SC_DATE |awk -F'/' '{print $2 $3}'`
	FILENAME_P1=SC${SC_DATE:2:2}$month_day

	tmp_title=`grep -r "sc-video-title sc-tvprograms-title" $TMP_TV_PRO -A1 |tail -1 |awk -F'<' '{print $1}'`
	FILENAME_P2=`echo $tmp_title`
	echo "INFO: Get video title: $FILENAME_P2"

}

convert_mp4_to_mp3(){
	/usr/local/bin/ffmpeg -i $SC_MP4  -map 0:a -b:a 128k $SC_MP3
	if [ $? -ne 0 ];then
		echo "Error: ffmpeg -i $SC_MP4  -map 0:a -b:a 128k $SC_MP3 error"
		echo -n "SC`date "+%y%m%d"`: " >> $ERROR_DL_LIST
		echo "ffmpeg -i $SC_MP4  -map 0:a -b:a 128k $SC_MP3" >> $ERROR_DL_LIST
	fi
}

#store MP4 video if resolution is 1080P, or just store mp3 file only
store_mp3_mp4(){

	read_title_of_sc

	echo "INFO: move $SC_MP3 to $HOME_OF_MP3/"
	echo y| mv $SC_MP3 $HOME_OF_MP3/"$FILENAME_P1 ($FILENAME_P2).mp3" 2>>$ERROR_DL_LOG
	if [ $? -ne 0 ];then
		echo "Error: move file $SC_MP3 to $HOME_OF_MP3 failed."
		echo -n "SC`date "+%y%m%d"`: " >> $ERROR_DL_LIST
		echo "move $SC_MP3 to $HOME_OF_MP3 failed" >> $ERROR_DL_LIST
	fi

	if [ "$RESOLUTION" == "1080P" ] || [ "$RESOLUTION" == "1080p" ];then
		echo "INFO: move $SC_MP4 to $HOME_OF_MP4/"
		echo y| mv $SC_MP4 $HOME_OF_MP4/"$FILENAME_P1 ($FILENAME_P2).mp4" 2>>$ERROR_DL_LOG
		if [ $? -ne 0 ];then
			echo "Error: move file $SC_MP4 to $HOME_OF_MP4 failed."
			echo -n "SC`date "+%y%m%d"`: " >> $ERROR_DL_LIST
			echo "move $SC_MP4 to $HOME_OF_MP4 failed" >> $ERROR_DL_LIST
		fi
	fi
}

main_process(){
	prepare_work
	# REsolution can be "1080P 720P 480P 360P 270P 144P"
	parse_url
	convert_mp4_to_mp3
	store_mp3_mp4
	send_email
}

main_process
