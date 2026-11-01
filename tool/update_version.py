"""يحدّث remote/version.json بعد كل بناء (يُستدعى من GitHub Actions)."""
import argparse
import json
import pathlib

p = argparse.ArgumentParser()
p.add_argument("--build", type=int, required=True)
p.add_argument("--name", required=True)
p.add_argument("--url", required=True)
p.add_argument("--sha", default="")
p.add_argument("--notes-file", default="")
p.add_argument("--force", default="false")
a = p.parse_args()

path = pathlib.Path("remote/version.json")
data = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
notes = pathlib.Path(a.notes_file).read_text(encoding="utf-8").strip() if a.notes_file else ""

data.update(
    latest_build=a.build,
    version_name=a.name,
    apk_url=a.url,
    sha256=a.sha,
    notes=notes,
)
data.setdefault("min_supported_build", 0)
if a.force.lower() == "true":
    data["min_supported_build"] = a.build

path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(data, ensure_ascii=False, indent=2))
