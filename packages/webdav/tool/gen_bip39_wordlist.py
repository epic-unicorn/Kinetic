"""Generate bip39_english.dart from the official BIP-0039 English wordlist."""

from pathlib import Path
import urllib.request

URL = "https://raw.githubusercontent.com/bitcoin/bips/master/bip-0039/english.txt"
OUT = Path(__file__).resolve().parents[1] / "lib" / "src" / "encryption" / "bip39_english.dart"


def main() -> None:
    words = urllib.request.urlopen(URL).read().decode().split()
    if len(words) != 2048:
        raise SystemExit(f"expected 2048 words, got {len(words)}")
    lines = [
        "/// Official BIP-0039 English wordlist (2048 words).",
        "/// Source: https://github.com/bitcoin/bips/blob/master/bip-0039/english.txt",
        "const kBip39English = <String>[",
    ]
    lines.extend(f"  '{w}'," for w in words)
    lines.append("];")
    lines.append("")
    OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"wrote {len(words)} words to {OUT}")


if __name__ == "__main__":
    main()
