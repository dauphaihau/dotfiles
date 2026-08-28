# make Finder/Quick Look use a useful MP4 thumbnail frame
# --force: replace an existing <original-name>-thumbnail.mp4; never overwrites the original input
# usage: vthumb input.mp4 [hold_seconds]
# usage: vthumb input.mp4 --at 52 --hold 0.05
# usage: vthumb --force --at 1:02 --hold 0.05 input.mp4
vthumb() {
  local force=0
  local thumb_at=""
  local hold_seconds=""
  local -a positional=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)
        force=1
        shift
        ;;
      --at)
        if [[ -z "$2" ]]; then
          echo "--at requires a timestamp, for example: --at 52, --at 1:02, or --at 1:02.5" >&2
          return 2
        fi
        thumb_at="$2"
        shift 2
        ;;
      --at=*)
        thumb_at="${1#--at=}"
        shift
        ;;
      --hold)
        if [[ -z "$2" ]]; then
          echo "--hold requires seconds, for example: --hold 0.05 or --hold 0.5" >&2
          return 2
        fi
        hold_seconds="$2"
        shift 2
        ;;
      --hold=*)
        hold_seconds="${1#--hold=}"
        shift
        ;;
      --help|-h)
        echo "usage: vthumb [--force] [--at seconds|M:SS|H:MM:SS] [--hold seconds] input.mp4 [hold_seconds]" >&2
        return 0
        ;;
      --)
        shift
        positional+=("$@")
        break
        ;;
      -*)
        echo "unknown option: $1" >&2
        echo "usage: vthumb [--force] [--at seconds|M:SS|H:MM:SS] [--hold seconds] input.mp4 [hold_seconds]" >&2
        return 2
        ;;
      *)
        positional+=("$1")
        shift
        ;;
    esac
  done

  local input="${positional[1]}"
  [[ -z "$hold_seconds" ]] && hold_seconds="${positional[2]:-0.05}"

  if [[ -z "$input" ]]; then
    echo "usage: vthumb [--force] [--at seconds|M:SS|H:MM:SS] [--hold seconds] input.mp4 [hold_seconds]" >&2
    return 2
  fi

  if [[ ! "$hold_seconds" =~ '^[0-9]+([.][0-9]+)?$' ]]; then
    echo "--hold must be seconds, for example: --hold 0.05 or --hold 0.5" >&2
    return 2
  fi

  if [[ ! -f "$input" ]]; then
    echo "file not found: $input" >&2
    return 1
  fi

  if ! command -v ffprobe >/dev/null 2>&1; then
    echo "ffprobe is not installed. Install it with: brew install ffmpeg" >&2
    return 127
  fi

  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ffmpeg is not installed. Install it with: brew install ffmpeg" >&2
    return 127
  fi

  local dir base stem output
  dir="${input:h}"
  base="${input:t}"
  stem="${base%.*}"
  output="${dir}/${stem}-thumbnail.mp4"

  if [[ "$output" == "$input" ]]; then
    echo "refusing to overwrite original: $input" >&2
    return 1
  fi

  if [[ -e "$output" && $force -ne 1 ]]; then
    echo "output already exists: $output" >&2
    echo "rerun with --force to replace it" >&2
    return 1
  fi

  local video_info audio_info width height duration fps fps_num fps_den has_audio
  video_info=$(ffprobe -v error \
    -select_streams v:0 \
    -show_entries stream=width,height,avg_frame_rate,r_frame_rate:format=duration \
    -of default=nw=1 "$input") || return 1

  width=$(printf '%s\n' "$video_info" | awk -F= '$1 == "width" { print $2; exit }')
  height=$(printf '%s\n' "$video_info" | awk -F= '$1 == "height" { print $2; exit }')
  duration=$(printf '%s\n' "$video_info" | awk -F= '$1 == "duration" { print $2; exit }')
  fps=$(printf '%s\n' "$video_info" | awk -F= '$1 == "avg_frame_rate" { print $2; exit }')
  [[ -z "$fps" || "$fps" == "0/0" ]] && fps=$(printf '%s\n' "$video_info" | awk -F= '$1 == "r_frame_rate" { print $2; exit }')
  [[ -z "$fps" || "$fps" == "0/0" ]] && fps="30/1"

  if [[ "$fps" == */* ]]; then
    fps_num="${fps%%/*}"
    fps_den="${fps##*/}"
    if [[ "$fps_den" == "0" ]]; then
      fps="30/1"
      fps_num=30
      fps_den=1
    fi
  fi

  audio_info=$(ffprobe -v error \
    -select_streams a:0 \
    -show_entries stream=sample_rate,channel_layout,channels \
    -of default=nw=1 "$input" 2>/dev/null)
  [[ -n "$audio_info" ]] && has_audio=1 || has_audio=0

  if [[ -z "$width" || -z "$height" || -z "$duration" ]]; then
    echo "could not inspect source video stream with ffprobe: $input" >&2
    return 1
  fi

  local black_log thumb_ts line black_end
  if [[ -n "$thumb_at" ]]; then
    if [[ "$thumb_at" =~ '^[0-9]+([.][0-9]+)?$' ]]; then
      thumb_ts="$thumb_at"
    elif [[ "$thumb_at" =~ '^([0-9]+):([0-9]{1,2})([.][0-9]+)?$' ]]; then
      thumb_ts=$(awk -v m="${match[1]}" -v s="${match[2]}${match[3]}" 'BEGIN { printf "%.3f", (m * 60) + s }')
    elif [[ "$thumb_at" =~ '^([0-9]+):([0-9]{1,2}):([0-9]{1,2})([.][0-9]+)?$' ]]; then
      thumb_ts=$(awk -v h="${match[1]}" -v m="${match[2]}" -v s="${match[3]}${match[4]}" 'BEGIN { printf "%.3f", (h * 3600) + (m * 60) + s }')
    else
      echo "--at must be seconds, M:SS, or H:MM:SS, for example: --at 52, --at 1:02, or --at 1:02.5" >&2
      return 2
    fi

    thumb_ts=$(awk -v t="$thumb_ts" -v d="$duration" 'BEGIN { if (t >= d) t = d > 0.20 ? d - 0.20 : 0; printf "%.3f", t }')
  else
    local scan_duration
    scan_duration=$(awk -v d="$duration" 'BEGIN { if (d > 30) print 30; else if (d > 0) print d; else print 30 }')

    black_log=$(ffmpeg -hide_banner -nostats -i "$input" \
      -t "$scan_duration" \
      -vf "blackdetect=d=0.05:pix_th=0.10" \
      -an -f null - 2>&1 >/dev/null)

    thumb_ts=""
    for line in ${(f)black_log}; do
      if [[ "$line" == *"black_start:0"* && "$line" =~ 'black_end:([0-9.]+)' ]]; then
        black_end="${match[1]}"
        thumb_ts=$(awk -v t="$black_end" -v d="$duration" 'BEGIN { t += 0.20; if (t >= d) t = d > 0.20 ? d - 0.20 : 0; printf "%.3f", t }')
        break
      fi
    done

    if [[ -z "$thumb_ts" ]]; then
      thumb_ts=$(awk -v d="$duration" 'BEGIN { t = d * 0.05; if (t < 1) t = 1; if (t > 5) t = 5; if (t >= d) t = d > 0.20 ? d - 0.20 : 0; printf "%.3f", t }')
    fi
  fi

  local sample_rate channel_layout channels
  sample_rate=$(printf '%s\n' "$audio_info" | awk -F= '$1 == "sample_rate" { print $2; exit }')
  channel_layout=$(printf '%s\n' "$audio_info" | awk -F= '$1 == "channel_layout" { print $2; exit }')
  channels=$(printf '%s\n' "$audio_info" | awk -F= '$1 == "channels" { print $2; exit }')
  [[ -z "$sample_rate" ]] && sample_rate=48000
  if [[ -z "$channel_layout" || "$channel_layout" == "unknown" ]]; then
    [[ "$channels" == "1" ]] && channel_layout="mono" || channel_layout="stereo"
  fi

  echo "source: $input"
  echo "video: ${width}x${height}, fps ${fps}, duration ${duration}s"
  [[ $has_audio -eq 1 ]] && echo "audio: ${sample_rate}Hz ${channel_layout}" || echo "audio: none"
  echo "thumbnail frame timestamp: ${thumb_ts}s"
  echo "thumbnail hold duration: ${hold_seconds}s"
  echo "output: $output"

  local filter_complex
  filter_complex="[0:v]trim=start=${thumb_ts}:duration=0.10,setpts=PTS-STARTPTS,fps=${fps},scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p,loop=loop=-1:size=1:start=0,trim=duration=${hold_seconds},setpts=PTS-STARTPTS[thumb]; [0:v]setpts=PTS-STARTPTS,fps=${fps},scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p[mainv]; [thumb][mainv]concat=n=2:v=1:a=0[v]"

  local -a ffmpeg_args
  ffmpeg_args=(-hide_banner -y -i "$input" -filter_complex "$filter_complex" -map "[v]")

  if [[ $has_audio -eq 1 ]]; then
    filter_complex="${filter_complex}; anullsrc=r=${sample_rate}:cl=${channel_layout},atrim=duration=${hold_seconds},asetpts=PTS-STARTPTS[silence]; [0:a]asetpts=PTS-STARTPTS[a0]; [silence][a0]concat=n=2:v=0:a=1[a]"
    ffmpeg_args=(-hide_banner -y -i "$input" -filter_complex "$filter_complex" -map "[v]" -map "[a]")
  fi

  ffmpeg "${ffmpeg_args[@]}" \
    -map_metadata 0 \
    -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
    -c:a aac -b:a 192k \
    -movflags +faststart \
    "$output" || return $?

  echo "verified output:"
  ffprobe -v error \
    -show_entries format=filename,duration,size:stream=index,codec_type,codec_name,width,height,avg_frame_rate,sample_rate,channel_layout \
    -of default=nw=1 "$output" || return $?

  if command -v qlmanage >/dev/null 2>&1; then
    qlmanage -r cache >/dev/null 2>&1 || true
    qlmanage -r >/dev/null 2>&1 || true
    echo "refreshed Quick Look thumbnail cache"
  fi

  echo "final output path: $output"
}
