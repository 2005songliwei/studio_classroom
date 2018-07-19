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


# url address
VIDEO_URL="http://m.studioclassroom.com/tv-programs.php?level=sc"
LINE_TV_VIDEO_URL=""
VIDEO_KEY=""
VIDEO_SERIAL_NUM=""
MP4_ADDR_URL_URL=""
MP4_REAL_ADDR=""


# REsolution can be "1080P 720P 480P 360P 270P 144P"
RESOLUTION=""


# temporary filename create by wget
TMP_TV_PRO="/tmp/tv-programs.html"
TMP_LINE_ME="/tmp/tv.line.me.html"
MP4_URL_FILE="/tmp/mp4-file"

SC_MP4="/tmp/SCV`date "+%y%m%d"`.mp4"
SC_MP3="/tmp/SC`date "+%y%m%d"`.mp3"

HOME_OF_MP3="$HOME/studio_classroom/SC_mp3"
HOME_OF_MP4="$HOME/studio_classroom/SC_mp4"


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


clean_tmp_file(){
	echo "INFO: remove tmeporary file: $TMP_TV_PRO $TMP_LINE_ME $MP4_URL_FILE"
	rm $TMP_TV_PRO $TMP_LINE_ME $MP4_URL_FILE $SC_MP4 $SC_MP3 -rf
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


# $1 is different VIDEO address, $2 is the output file create by wget.
wget_html(){

	i=0
	echo "INFO: wget --quiet -c $1 -O $2"
	tsocks wget --quiet $1 -O $2
	while [ $? -ne 0 ]
	do
		i=$((i+1))
		if [ "$i" == 20 ];then
			echo "ERROR: cat not connect $1, stopped"
			exit 1
		fi
		sleep 5
		echo "Error: wget $1 failed, retry... $i"
		tsocks wget -c --quiet $1 -O $2
	done

}

prase_url(){

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
	echo "INFO: Successful got MP4 Address: $$MP4_REAL_ADDR"

	# download the video and store it as /tmp/SC.mp4
	wget_html $MP4_REAL_ADDR $SC_MP4
}

convert_mp4_to_mp3(){
	ffmpeg -i $SC_MP4  -map 0:a -b:a 128k $SC_MP3
}

#store MP4 video if resolution is 1080P, or just store mp3 file only
store_mp3_mp4(){

	mv $SC_MP3 $HOME_OF_MP3/

	if [ "$RESOLUTION" == "1080P" ] || [ "$RESOLUTION" == "1080p" ];then
		echo "INFO: copy $SC_MP4 to $HOME_OF_MP4"
		mv $SC_MP4 $HOME_OF_MP4/
	fi
}


read_resolution
clean_tmp_file
check_dir $HOME_OF_MP3 $HOME_OF_MP4
# REsolution can be "1080P 720P 480P 360P 270P 144P"
prase_url
convert_mp4_to_mp3
store_mp3_mp4
