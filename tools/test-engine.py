"""Run isolated native engine fixtures and restart verification against local MariaDB."""
from pathlib import Path
import os
import subprocess
import time
import sys

root = Path(__file__).resolve().parents[1]
log = root / '.local/engine-test.log'
env = dict(os.environ, NOSTALGIA_TEST='1')
if '--live-restart' in sys.argv:
    env['NOSTALGIA_LIVE_RESTART_VERIFY'] = '1'
elif '--restart' in sys.argv:
    env['NOSTALGIA_RESTART_VERIFY'] = '1'
else:
    # Reset only explicitly named disposable fixtures. Playable testers are untouched.
    subprocess.run([sys.executable, str(root / 'tools/provision-nostalgia.py'), '--fixtures'], check=True)
    names = "'Test Bastion','Test Medic','Test Ranger','Test Assault'"
    sql = f"""
START TRANSACTION;
DELETE i FROM player_items i JOIN players p ON i.player_id=p.id
WHERE p.name IN ({names});
DELETE k FROM kv_store k JOIN players p ON k.key_name LIKE CONCAT('player.',p.id,'.nostalgia-v1.%')
WHERE p.name IN ({names});
UPDATE players SET level=1,experience=0,health=500,healthmax=500,mana=0,manamax=100,
conditions='',posx=1008,posy=1010,posz=7 WHERE name IN ({names});
COMMIT;
"""
    subprocess.run([str(root / '.local/mariadb-11.4.13-winx64/bin/mariadb.exe'),
                    f'--defaults-file={root / ".local/database.ini"}', 'nostalgia'],
                   input=sql, text=True, check=True, capture_output=True)
with log.open('w', encoding='utf-8') as output:
    process = subprocess.Popen([str(root / 'canary.exe')], cwd=root, env=env, stdout=output, stderr=subprocess.STDOUT)
    try:
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            time.sleep(0.25)
            text = log.read_text(encoding='utf-8', errors='replace')
            if 'NOSTALGIA ENGINE PASS:' in text or 'NOSTALGIA RESTART PASS:' in text:
                print(next(line for line in text.splitlines() if 'NOSTALGIA ' in line and ' PASS:' in line))
                break
            if 'Lua Script Error' in text or process.poll() is not None:
                raise RuntimeError('Engine test failed. Inspect .local/engine-test.log.')
        else:
            raise RuntimeError('Engine fixture timed out. Inspect .local/engine-test.log.')
    finally:
        if process.poll() is None:
            process.terminate()
        process.wait(timeout=10)
