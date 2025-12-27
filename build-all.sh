#!/usr/bin/env bash

set -euo pipefail

rm -rf .west

echo "🐳 Launching podman container for ZMK build..."

podman run -it --rm --security-opt label=disable \
  --workdir /zmk-config \
  -v "$(pwd)":/zmk-config \
  zmkfirmware/zmk-build-arm:3.5-branch \
  /bin/bash -c "
set -euo pipefail

ZMK_APP_PATH='zmk/app'
BUILD_DIR='builds'

# Init west workspace
echo '🔧 Initializing west workspace...'
west init -l config
west update
west zephyr-export

# Parse and build each target
echo '🛠️  Building firmware targets...'

python3 << 'PYTHON_SCRIPT'
import yaml
import subprocess
import sys
import shutil
import os

with open('/zmk-config/build.yaml', 'r') as f:
    config = yaml.safe_load(f)

FIRMWARE_OUT = '/zmk-config/firmwares'
if os.path.exists(FIRMWARE_OUT):
    shutil.rmtree(FIRMWARE_OUT)
os.makedirs(FIRMWARE_OUT, exist_ok=True)

subprocess.run(['west', 'zephyr-export'], cwd='/zmk-config', check=True)

for target in config.get('include', []):



    board = target['board']
    artifact = target['artifact-name']
    
    if 'cornix' in artifact:
        keymap = '/zmk-config/config/cornix.keymap'
    elif 'totem' in artifact:
        keymap = '/zmk-config/config/totem.keymap'
    elif 'forager' in artifact:
        keymap = '/zmk-config/config/forager.keymap'
    elif 'dongle_reset' in artifact:
        keymap = '/zmk-config/config/default.keymap'
    else:
        keymap = '/zmk-config/config/default.keymap'
    
    cmd = [
        'west', 'build', '-s', 'zmk/app',
        '-p',
        '-b', board,
        '-d', f'builds/{artifact}'
    ]
    
    shield = target.get('shield', '')
    snippet = target.get('snippet', '')
    
    extra_args = []
    if shield:
        extra_args.append(f'-DSHIELD={shield}')
        
    if snippet:

        snippet_parts = snippet.split()
        for part in snippet_parts:
            extra_args.append(f'-DSNIPPET={part}')
    if keymap:
        extra_args.append(f'-DKEYMAP_FILE={keymap}')
    
    cmake_args = target.get('cmake-args', '')
    if cmake_args:
        import shlex
        for arg in shlex.split(cmake_args):
            if arg.startswith('-D'):
                fixed_arg = arg.replace('../../', '/zmk-config/')
                extra_args.append(fixed_arg)
    
    cmd.append('--')
    cmd.extend(extra_args)
    
    print(f'Building: {artifact}')
    print(f'  Board: {board}')
    print(f'  Shield: {shield}')
    print(f'  Keymap: {keymap}')
    
    result = subprocess.run(cmd, cwd='/zmk-config')
    if result.returncode != 0:
        print(f'❌ Failed to build {artifact}')
        sys.exit(1)
    else:
        print(f'✅ Built: {artifact}')

# Collect firmware files
print('📦 Collecting firmware files...')

for root, dirs, files in os.walk('/zmk-config/builds'):



    for f in files:
        if f == 'zmk.uf2':
            dir_path = os.path.dirname(root)
            dir_name = os.path.basename(dir_path)
            src = os.path.join(root, f)
            dst = os.path.join(FIRMWARE_OUT, f'{dir_name}.uf2')
            shutil.copy2(src, dst)
            print(f'✅ Copied: {dir_name}.uf2')
            break

print('All firmwares collected:')
os.system('ls -lh /zmk-config/firmwares')
PYTHON_SCRIPT

echo '🎉 All builds completed successfully!'
"
