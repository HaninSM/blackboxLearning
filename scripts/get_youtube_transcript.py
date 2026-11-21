#!/usr/bin/env python3
"""
YouTube Transcript & Metadata Extractor for MQL5 EA Architect Skill
"""
import sys
import re
import json
import argparse
from urllib.parse import urlparse, parse_qs

def extract_video_id(url_or_id: str) -> str:
    url_or_id = url_or_id.strip()
    # Match standard ID format (11 chars)
    if re.fullmatch(r"[a-zA-Z0-9_-]{11}", url_or_id):
        return url_or_id
    
    parsed = urlparse(url_or_id)
    if parsed.hostname in ("www.youtube.com", "youtube.com", "m.youtube.com"):
        if parsed.path == "/watch":
            qs = parse_qs(parsed.query)
            if "v" in qs:
                return qs["v"][0]
        elif parsed.path.startswith(("/embed/", "/v/", "/shorts/", "/live/")):
            return parsed.path.split("/")[2]
    elif parsed.hostname == "youtu.be":
        return parsed.path.lstrip("/").split("?")[0]
    
    # Generic regex fallback
    match = re.search(r"(?:v=|\/|youtu\.be\/)([a-zA-Z0-9_-]{11})", url_or_id)
    if match:
        return match.group(1)
    
    raise ValueError(f"Could not extract YouTube video ID from: {url_or_id}")

def get_transcript_via_api(video_id: str):
    from youtube_transcript_api import YouTubeTranscriptApi
    try:
        # List all transcripts to find best match
        transcript_list = YouTubeTranscriptApi.list_transcripts(video_id)
        
        # Try manual or generated in id or en
        preferred_languages = ['id', 'en']
        transcript = None
        
        # Try preferred languages directly
        for lang in preferred_languages:
            try:
                transcript = transcript_list.find_transcript([lang])
                break
            except Exception:
                continue
                
        # If not found, get any available transcript
        if not transcript:
            for t in transcript_list:
                transcript = t
                break
                
        if transcript:
            # If transcript is not in id or en, try translating to en if possible
            if transcript.language_code not in preferred_languages and transcript.is_translatable:
                try:
                    transcript = transcript.translate('en')
                except Exception:
                    pass
            return transcript.fetch()
    except Exception as e:
        return None

def get_metadata_and_transcript_via_ytdlp(video_id: str):
    import yt_dlp
    ydl_opts = {
        'skip_download': True,
        'writesubtitles': True,
        'writeautomaticsub': True,
        'subtitleslangs': ['id', 'en'],
        'quiet': True,
        'no_warnings': True,
    }
    url = f"https://www.youtube.com/watch?v={video_id}"
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False)
        return {
            'title': info.get('title', ''),
            'description': info.get('description', ''),
            'duration': info.get('duration', 0),
            'channel': info.get('uploader', ''),
            'subtitles': info.get('subtitles', {}),
            'automatic_captions': info.get('automatic_captions', {})
        }

def format_transcript(transcript_entries) -> str:
    lines = []
    current_time_str = ""
    chunk = []
    
    for entry in transcript_entries:
        text = entry.get('text', '').strip()
        start = int(entry.get('start', 0))
        minutes = start // 60
        seconds = start % 60
        time_tag = f"[{minutes:02d}:{seconds:02d}]"
        
        if not current_time_str:
            current_time_str = time_tag
            
        chunk.append(text)
        # Group into ~1 minute or ~10 sentences
        if len(chunk) >= 6:
            lines.append(f"{current_time_str} " + " ".join(chunk))
            chunk = []
            current_time_str = ""
            
    if chunk:
        lines.append(f"{current_time_str} " + " ".join(chunk))
        
    return "\n".join(lines)

def main():
    parser = argparse.ArgumentParser(description="Fetch YouTube Video Transcript and Metadata")
    parser.add_argument("url", help="YouTube URL or Video ID")
    parser.add_argument("--output", "-o", help="Output file path (optional)")
    args = parser.parse_args()

    try:
        video_id = extract_video_id(args.url)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    result_data = {
        'video_id': video_id,
        'url': f"https://www.youtube.com/watch?v={video_id}",
        'title': '',
        'transcript': ''
    }

    # Fetch metadata via yt-dlp
    try:
        meta = get_metadata_and_transcript_via_ytdlp(video_id)
        result_data['title'] = meta.get('title', '')
        result_data['channel'] = meta.get('channel', '')
        result_data['description'] = meta.get('description', '')[:500] # preview
    except Exception as e:
        pass

    # Fetch transcript
    transcript_entries = get_transcript_via_api(video_id)
    if transcript_entries:
        result_data['transcript'] = format_transcript(transcript_entries)
    else:
        result_data['transcript'] = "[NO TRANSCRIPT FOUND OR TRANSCRIPT DISABLED FOR THIS VIDEO]"

    output_text = f"# YouTube Strategy Ingestion: {result_data.get('title', video_id)}\n"
    output_text += f"- **Channel:** {result_data.get('channel', 'Unknown')}\n"
    output_text += f"- **URL:** {result_data['url']}\n"
    output_text += f"- **Video ID:** {video_id}\n\n"
    output_text += "## Transcript:\n"
    output_text += result_data['transcript']

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(output_text)
        print(f"Transcript successfully saved to {args.output}")
    else:
        print(output_text)

if __name__ == "__main__":
    main()
