 #! /bin/sh
 
 file="bbb_sunflower_2160p_30fps_normal.mp4"
 timestamp=`date +%s`
 ffmpeg="docker run --rm -it --workdir /tmp -v $PWD:/tmp kynothon/moviola:4.0-alpine "
 bento4="docker run -it --rm -u $(id -u):$(id -g) -v $PWD:/tmp --workdir /tmp ggoussard/bento4docker "
 
 echo "Getting the file"
 curl -LO http://distribution.bbb3d.renderfarming.net/video/mp4/bbb_sunflower_2160p_30fps_normal.mp4
 
 echo "Creating a workdir $timestamp"
 mkdir -p "${timestamp}"
 
 echo "File analysis: ${file}"
 ffprobe -v quiet -print_format json -show_format -show_streams "${file}" > "${timestamp}/ffprobe.json"
 
 echo "Demux tracks"
 cat "${timestamp}/ffprobe.json" | \
     jq -r ".streams[] | \"-c:\(.codec_type[0:1]) copy -map 0:\(.index) ${timestamp}/\(.codec_type)_\(.index).mp4\"" | \
     xargs ffmpeg -v quiet -y -i ${file}
 
 echo "Transcode video tracks"
video="${ffmpeg} -i ${timestamp}/video_0.mp4"
 
 for bitrate in 2000 3000 4000 5000 7000; do
     video="${video} -filter:v scale=1920:-1 -movflags frag_keyframe+empty_moov+default_base_moof+faststart -bf 2 -g 90 -sc_threshold 0 -an -strict experimental -profile:v baseline -b:v ${bitrate}k -f mp4         ${timestamp}/video_0_${bitrate}.fmp4"
 done
 
 ${video}
 
 echo "Fragment the audio tracks"
 for audio in ${timestamp}/audio_[0-9].mp4; do
     filename=`basename ${audio} .mp4`
     ${ffmpeg} -i ${audio} -movflags frag_keyframe+empty_moov+default_base_moof+faststart  -vn -strict experimental -c:a copy -f mp4 -frag_duration 3000000  ${timestamp}/${filename}.fmp4
 done
 
 echo "Manifest generation"
 ${bento4} mp4dash -f -o /tmp/output -v --no-split --hls --profiles=on-demand "/tmp/${timestamp}/*.fmp4"
 
 echo "The Manifests, audio and video files are in the output folder"
 echo "work files are in ${timestamp}"