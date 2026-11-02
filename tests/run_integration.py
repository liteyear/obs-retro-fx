from pathlib import Path
import os, subprocess, time, shutil
project=Path(__file__).resolve().parents[1]
p=project.parent
runtime=Path(os.environ.get('LITEYEAR_OBS_PREFIX',str(p/'test-runtime/root') if (p/'test-runtime/root').exists() else '/'))
env=os.environ.copy()
env.update(LD_LIBRARY_PATH=str(runtime/'usr/lib/x86_64-linux-gnu')+':'+env.get('LD_LIBRARY_PATH',''),
           DISPLAY='127.0.0.1:97', LIBGL_ALWAYS_SOFTWARE='1',
           LUA_CPATH=str(runtime/'usr/lib/x86_64-linux-gnu/obs-scripting/?.so')+';;')
xvfb=str(runtime/'usr/bin/Xvfb') if (runtime/'usr/bin/Xvfb').exists() else shutil.which('Xvfb')
(project/'tests/rendered').mkdir(exist_ok=True)
x=subprocess.Popen([xvfb,':97','-screen','0','1280x720x24','-ac',
    '-nolisten','local','-nolisten','unix','-listen','inet','-listen','inet6'],env=env,
    stdout=open(project/'tests/xvfb.log','w'),stderr=subprocess.STDOUT)
try:
    time.sleep(1)
    r=subprocess.run([str(project/'tests/render_harness'),str(runtime),
        str(project/'package/Liteyear-Retro-FX/liteyear-retro-fx.lua'),str(project/'tests/rendered')],
        env=env,stdout=open(project/'tests/render.log','w'),stderr=subprocess.STDOUT,timeout=110)
    print('Harness exit:',r.returncode)
finally:
    x.terminate();x.wait(timeout=5)
print((project/'tests/render.log').read_text()[-18000:])
raise SystemExit(r.returncode)
