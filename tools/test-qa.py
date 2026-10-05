"""Smoke actual playable Testers without changing their equipment/progression.

Requires no running Canary/client instance; uses an isolated client UI profile.
The test restores each character's starting position on normal logout.
"""
from pathlib import Path
import os
import subprocess
import shutil
import time
import sys

root=Path(__file__).resolve().parents[1]
client=root.parent/'NostalgiaClient'
env=dict(os.environ,NOSTALGIA_QA_TEST='1')
env.pop('NOSTALGIA_HD_PROOF',None)
env.pop('NOSTALGIA_HD_QA',None)
if '--hd' in sys.argv or '--hd-fallback' in sys.argv:
    env['NOSTALGIA_HD_QA']='1'
    if '--hd' in sys.argv: env['NOSTALGIA_HD_PROOF']='1'
env.pop('NOSTALGIA_LIVE_TEST',None)
env.pop('NOSTALGIA_TEST',None)
profile=client/'.local/qa-profile'
profile.mkdir(parents=True,exist_ok=True)
config=client/'.local/live-profile/config.otml'
if config.is_file(): shutil.copy2(config,profile/'config.otml')
server_log=root/'.local/qa-server.log'
client_log=root/'.local/qa-client.log'
with server_log.open('w',encoding='utf-8') as sout,client_log.open('w',encoding='utf-8') as cout:
    server=subprocess.Popen([str(root/'canary.exe')],cwd=root,env=env,stdout=sout,stderr=subprocess.STDOUT)
    process=None
    try:
        deadline=time.monotonic()+30
        while time.monotonic()<deadline:
            time.sleep(.2)
            text=server_log.read_text(errors='replace')
            if 'Lua Script Error' in text or server.poll() is not None: raise RuntimeError('QA server failed; inspect .local/qa-server.log')
            if 'server online!' in text: break
        else: raise RuntimeError('QA server startup timeout')
        process=subprocess.Popen([str(client/'otclient.exe'),f'--user-dir={profile}'],cwd=client,env=env,stdout=cout,stderr=subprocess.STDOUT)
        deadline=time.monotonic()+125
        while time.monotonic()<deadline:
            time.sleep(.2)
            sl=server_log.read_text(errors='replace')
            cl=(client/'otclient.log').read_text(errors='replace')
            if 'Lua Script Error' in sl: raise RuntimeError('QA native map/test failed; inspect .local/qa-server.log')
            if '[error]' in cl: raise RuntimeError('QA client failed; inspect NostalgiaClient/otclient.log')
            if process.poll() is not None:
                assert 'NOSTALGIA QA CLIENT PASS:' in cl,'Missing QA client success marker'
                assert sl.count('NOSTALGIA QA TESTER PASS:')==4,'Missing playable Tester state checks'
                print('PASS: four actual Testers; authoritative Skills, 15.25 modules, native docking/collapse, QA travel, both stair pairs, movement/door use/world chest, unchanged inventory/progression, restored positions.')
                break
        else: raise RuntimeError('QA smoke timeout')
    finally:
        if process and process.poll() is None: process.terminate(); process.wait(timeout=10)
        if server.poll() is None: server.terminate()
        server.wait(timeout=10)
