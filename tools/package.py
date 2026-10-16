from pathlib import Path
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / 'dist'
PACKAGE = DIST / 'Zomput-Survivor_Signal'
DIST.mkdir(exist_ok=True)
if PACKAGE.exists():
    assert PACKAGE.resolve().parent == DIST.resolve()
    shutil.rmtree(PACKAGE)
target = PACKAGE / 'Contents/mods/ZomputSurvivorSignal'
shutil.copytree(ROOT / 'Contents/mods/ZomputSurvivorSignal', target)
for name in ('preview.png', 'workshop.txt'):
    shutil.copy2(ROOT / name, PACKAGE / name)
with zipfile.ZipFile(DIST / 'Zomput-Survivor_Signal.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(target.rglob('*')):
        archive.write(path, path.relative_to(PACKAGE / 'Contents/mods'))
print('Packaged Zomput-Survivor_Signal.')
