# Upload PNGs as Roblox Images (usable as ImageLabel.Image) to the game's group with Open Cloud.
# The key is read from the env var named by roblox.json "robloxKeyEnv" and never printed.
#   python3 tools/ui/upload_images.py --group <groupId> --prefix "ROYF icon" <png> [<png> ...]
# Prints one JSON line per file: {"name": <file stem>, "assetId": <id>}
import argparse
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request
import uuid

BASE = "https://apis.roblox.com/assets/v1"
ROOT = pathlib.Path(__file__).resolve().parents[2]


def key() -> str:
    env = json.loads((ROOT / "roblox.json").read_text())["robloxKeyEnv"]
    k = os.environ.get(env)
    if not k:
        sys.exit(f"{env} is not set")
    return k


def call(req: urllib.request.Request) -> dict:
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code}: {e.read().decode(errors='replace')[:400]}")


def upload(path: pathlib.Path, name: str, group: str, k: str) -> str:
    request = {
        "assetType": "Image",
        "displayName": name[:50],
        "description": "Run Over Your Friends UI icon",
        "creationContext": {"creator": {"groupId": group}},
    }
    boundary = uuid.uuid4().hex
    body = bytearray()
    body += (f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n'
             f"Content-Type: application/json\r\n\r\n{json.dumps(request)}\r\n").encode()
    body += (f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{path.name}"\r\n'
             "Content-Type: image/png\r\n\r\n").encode()
    body += path.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(f"{BASE}/assets", data=bytes(body), method="POST")
    req.add_header("x-api-key", k)
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    op = call(req)
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(2)
        poll = urllib.request.Request(f"{BASE}/{op['path']}")
        poll.add_header("x-api-key", k)
        op = call(poll)
    if not op.get("done") or "error" in op:
        sys.exit(f"{path.name}: not processed: {op.get('error', 'timed out')}")
    return op["response"]["assetId"]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+", type=pathlib.Path)
    ap.add_argument("--group", required=True)
    ap.add_argument("--prefix", default="ROYF icon")
    args = ap.parse_args()
    k = key()
    for f in args.files:
        aid = upload(f, f"{args.prefix} {f.stem}", args.group, k)
        print(json.dumps({"name": f.stem, "assetId": aid}), flush=True)


if __name__ == "__main__":
    main()
