"""Idempotently add four local sandbox characters; never reset existing progress."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
local = root / '.local'
credentials = json.loads((local / 'credentials.json').read_text(encoding='utf-8-sig'))
password_hash = hashlib.sha1(credentials['account'].encode()).hexdigest()
sql = f"""
INSERT INTO accounts (name, email, password, premdays)
SELECT 'nostalgia', 'sandbox@nostalgia.local', '{password_hash}', 365
WHERE NOT EXISTS (SELECT 1 FROM accounts WHERE name='nostalgia');
"""
for vocation, name in enumerate(('Bastion', 'Medic', 'Ranger', 'Assault'), 20):
    sql += f"""
INSERT INTO players (name, account_id, vocation, level, experience, health, healthmax, mana, manamax, cap, town_id, posx, posy, posz, looktype, conditions)
SELECT '{name} Tester', id, {vocation}, 1, 0, 500, 500, 0, 100, 10000, 1, 1008, 1010, 7, 128, ''
FROM accounts WHERE name='nostalgia' AND NOT EXISTS (SELECT 1 FROM players WHERE name='{name} Tester');
"""
    if '--fixtures' in sys.argv:
        sql += f"""
INSERT INTO players (name, account_id, vocation, level, experience, health, healthmax, mana, manamax, cap, town_id, posx, posy, posz, looktype, conditions)
SELECT 'Test {name}', id, {vocation}, 1, 0, 500, 500, 0, 100, 10000, 1, 1008, 1010, 7, 128, ''
FROM accounts WHERE name='nostalgia' AND NOT EXISTS (SELECT 1 FROM players WHERE name='Test {name}');
"""
subprocess.run([str(local / 'mariadb-11.4.13-winx64/bin/mariadb.exe'), f'--defaults-file={local / "database.ini"}', 'nostalgia'], input=sql, text=True, check=True, capture_output=True)
print('Four persistent sandbox characters available. Login: sandbox@nostalgia.local; password: ignored .local/credentials.json account field.')
