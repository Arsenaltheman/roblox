"""Turn the raw generated sounds in assets/audio/raw/ into game-ready files in assets/audio/game/.

For each sound: cut trailing silence, cap the length, add a short fade-out and peak-normalize to
-1 dBFS. Loudness balance between sounds is done in src/shared/Config/Sounds.luau (volume per key),
so the files themselves are all as loud as they can be without clipping.

Run: python3 -I tools/audio/process.py   (needs ffmpeg)
"""

import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "assets" / "audio" / "raw"
OUT = ROOT / "assets" / "audio" / "game"

# Longest each sound may be, in seconds. Anything not listed is capped at 3 s.
MAX_LENGTH = {
    "click": 0.25,
    "toast": 0.8,
    "coin": 0.6,
    "buy": 0.8,
    "lock": 0.9,
    "caught": 1.2,
    "stolen": 2.0,
    "doors": 2.5,
    "giftReady": 1.0,
    "voice": 3.5,
}
FADE = 0.12
PEAK_DB = -1.0


def max_volume(path: pathlib.Path) -> float:
    result = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", "volumedetect", "-f", "null", "-"],
        capture_output=True,
        text=True,
        check=True,
    )
    match = re.search(r"max_volume: (-?[\d.]+) dB", result.stderr)
    return float(match.group(1)) if match else 0.0


def duration(path: pathlib.Path) -> float:
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
        capture_output=True,
        text=True,
        check=True,
    )
    return float(result.stdout.strip())


def process(src: pathlib.Path, dst: pathlib.Path, cap: float) -> None:
    tmp = dst.with_suffix(".tmp.wav")
    # Remove trailing silence by reversing, trimming leading silence, reversing back.
    trim = "areverse,silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.05,areverse"
    subprocess.run(
        ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(src), "-af", trim, "-t", str(cap), str(tmp)],
        check=True,
    )
    length = duration(tmp)
    gain = PEAK_DB - max_volume(tmp)
    fade_start = max(0.0, length - FADE)
    chain = f"volume={gain:.2f}dB,afade=t=out:st={fade_start:.3f}:d={FADE}"
    subprocess.run(
        ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(tmp), "-af", chain,
         "-c:a", "libvorbis", "-q:a", "5", str(dst)],
        check=True,
    )
    tmp.unlink()
    print(f"{dst.name:28s} {length:5.2f}s  gain {gain:+.1f} dB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for src in sorted(RAW.rglob("*.mp3")):
        if src.parent.name == "voice_batches":
            continue  # source recordings for split_voices.py
        key = src.stem
        group = src.parent.name  # "raw" for sfx, "voice" for voice lines
        cap = MAX_LENGTH.get(key, MAX_LENGTH["voice"] if group == "voice" else 3.0)
        dst_dir = OUT / group if group != "raw" else OUT
        dst_dir.mkdir(parents=True, exist_ok=True)
        process(src, dst_dir / f"{key}.ogg", cap)


if __name__ == "__main__":
    main()
