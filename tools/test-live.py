"""Run real Canary/OTClient network gameplay on disposable Test characters."""
from pathlib import Path
import os
import subprocess
import time
import socket
import threading
import struct
import zlib

root = Path(__file__).resolve().parents[1]
client = root.parent / 'NostalgiaClient'
env = dict(os.environ, NOSTALGIA_LIVE_TEST='1')
if os.getenv('NOSTALGIA_TRACE_HEADER') == '1':
    env['NOSTALGIA_LOGIN_PORT'] = '7199'
    def proxy():
        with socket.socket() as listener:
            listener.bind(('127.0.0.1',7199)); listener.listen()
            incoming,_ = listener.accept()
            outgoing = socket.create_connection(('127.0.0.1',7171))
            first = incoming.recv(8192)
            size = struct.unpack('<H',first[:2])[0]
            crc = struct.unpack('<I',first[2:6])[0]
            print('Non-secret login envelope:',len(first),size,'checksum matches',crc==zlib.adler32(first[6:]),'prelude',first[:24].hex(),flush=True)
            outgoing.sendall(first)
            def forward(source,target):
                try:
                    while data:=source.recv(8192): target.sendall(data)
                except OSError: pass
                finally:
                    source.close(); target.close()
            threading.Thread(target=forward,args=(incoming,outgoing),daemon=True).start()
            forward(outgoing,incoming)
    threading.Thread(target=proxy,daemon=True).start()
server_log = root / '.local/live-server.log'
client_log = root / '.local/live-client.log'
profile = client / '.local/live-profile'
profile.mkdir(parents=True, exist_ok=True)
with server_log.open('w',encoding='utf-8') as sout, client_log.open('w',encoding='utf-8') as cout:
    server = subprocess.Popen([str(root/'canary.exe')],cwd=root,env=env,stdout=sout,stderr=subprocess.STDOUT)
    process = None
    try:
        time.sleep(2)
        process = subprocess.Popen([str(client/'otclient.exe'),f'--user-dir={profile}'],cwd=client,env=env,stdout=cout,stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 190
        while time.monotonic() < deadline:
            time.sleep(.5)
            text = server_log.read_text(encoding='utf-8',errors='replace')
            if 'Lua Script Error' in text or server.poll() is not None:
                if 'Lua Script Error' in text:
                    start = text.index('Lua Script Error')
                    print(text[start:start+1700],flush=True)
                raise RuntimeError(f'Native server test failed (exit={server.poll()}): inspect .local/live-server.log')
            if process.poll() is not None:
                log = (client/'otclient.log').read_text(encoding='utf-8',errors='replace')
                if 'NOSTALGIA CLIENT PASS:' not in log:
                    raise RuntimeError('Native client test failed: inspect NostalgiaClient/otclient.log')
                scope = os.getenv('NOSTALGIA_TEST_CLASS') or 'four classes/twelve families'
                print('PASS: live Canary/OTClient, ' + scope + ', native attacks/supplies/skills, defence, healing, XP, loot, shop, HUD and two deaths per class.')
                break
        else:
            raise RuntimeError('Live test timed out; inspect local logs.')
    finally:
        if process and process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        if server.poll() is None:
            server.terminate()
        server.wait(timeout=10)

# Reload the characters after real attacks, purchases, two deaths and logout.
import sys
subprocess.run([sys.executable, str(root/'tools/test-engine.py'), '--live-restart'], env=env, check=True)
