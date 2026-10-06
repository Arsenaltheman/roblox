"""Split the batched voice recordings in assets/audio/raw/voice_batches/ into one file per line.

Each batch was generated as several lines separated by 1.5 s pauses (see assets/audio/PROMPTS.md).
The pauses are found with ffmpeg's silencedetect and every segment is written to
assets/audio/raw/voice/<key>.mp3, where the key matches src/shared/Config/Sounds.luau VoiceIds.

Run: python3 -I tools/audio/split_voices.py   (needs ffmpeg), then tools/audio/process.py.
"""

import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
BATCHES = ROOT / "assets" / "audio" / "raw" / "voice_batches"
OUT = ROOT / "assets" / "audio" / "raw" / "voice"

LINES = {
    "b1": ["CactusCarl", "TumbleweedTim", "SirHayBale", "PebbleProspector", "DustyBunny", "LilLantern",
           "BootsMcGoat", "PicklePete", "SaddleSnail", "HorseshoeHank", "CornbreadCorgi"],
    "b2": ["WindmillWilly", "BurritoBronco", "YeehawYak", "RodeoRooster", "WagonWheelWalrus", "PrairiePancake",
           "CoyoteKazoo", "SheriffShrimpo", "BanjoBison", "LassoLlama", "TinStarToad"],
    "b3": ["CanyonCapybara", "GoldPanPanda", "GoldToothGoose", "RattlesnakeRex", "Thunderhoof", "DynamoArmadillo",
           "SteamboatSloth", "SteamEngineStallion", "CycloneCoyote", "SunsetSerpent", "GoldenSpurGriffin"],
    "b4": ["CanyonColossus", "MidnightMarauder", "BlackHatBadger", "PhantomRider", "DustDevilDragon", "CloudCowboy",
           "LaLocomotoraLoca", "DeputyDuck", "GoldenLocomotive", "DiamondDesperado"],
    "ann": ["ann_itsA", "ann_trainArriving", "ann_goldenExpress", "ann_thief", "ann_frontier", "ann_weather",
            "ann_strongbox"],
}
PAD = 0.08  # seconds of breathing room kept around each line


def pauses(path: pathlib.Path) -> list[tuple[float, float]]:
    result = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", "silencedetect=n=-40dB:d=0.8", "-f", "null", "-"],
        capture_output=True,
        text=True,
        check=True,
    )
    starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", result.stderr)]
    ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", result.stderr)]
    return list(zip(starts, ends))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for batch, keys in LINES.items():
        src = BATCHES / f"{batch}.mp3"
        if not src.exists():
            print(f"skip {batch}: not downloaded")
            continue
        gaps = pauses(src)
        if len(gaps) != len(keys) - 1:
            raise SystemExit(f"{batch}: expected {len(keys) - 1} pauses, found {len(gaps)}; split by hand")
        bounds = [0.0] + [e for _, e in gaps]
        stops = [s for s, _ in gaps] + [None]
        for key, start, stop in zip(keys, bounds, stops):
            args = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-ss", f"{max(0.0, start - PAD):.3f}"]
            if stop is not None:
                args += ["-to", f"{stop + PAD:.3f}"]
            # -ss/-to before -i seek the input; re-encoding keeps the cut sample-accurate.
            args += ["-i", str(src), str(OUT / f"{key}.mp3")]
            subprocess.run(args, check=True)
        print(f"{batch}: {len(keys)} lines")


if __name__ == "__main__":
    main()
