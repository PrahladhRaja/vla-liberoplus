"""Stream a zip archive to stdout as a tar archive, stripping a path prefix, without extracting anything.

Used to turn LIBERO-Plus's assets.zip (~449k files) into a single squashfs image:
    python zip2tar.py assets.zip "<prefix inside zip>" | mksquashfs - assets.sqfs -tar -comp gzip
so the individual files never land on Turing's shared filesystem.
"""

import sys
import tarfile
import time
import zipfile

zip_path, prefix = sys.argv[1], sys.argv[2]
z = zipfile.ZipFile(zip_path)
now = int(time.time())
n = 0
with tarfile.open(fileobj=sys.stdout.buffer, mode="w|", format=tarfile.PAX_FORMAT) as tar:
    for info in z.infolist():
        if not info.filename.startswith(prefix):
            continue
        rel = info.filename[len(prefix):].lstrip("/")
        if not rel or ".." in rel.split("/"):
            continue
        member = tarfile.TarInfo(rel.rstrip("/"))
        member.mtime = now
        if info.is_dir():
            member.type, member.mode = tarfile.DIRTYPE, 0o755
            tar.addfile(member)
        else:
            member.size, member.mode = info.file_size, 0o644
            with z.open(info) as src:
                tar.addfile(member, src)
            n += 1
print(f"zip2tar: streamed {n} files", file=sys.stderr)
