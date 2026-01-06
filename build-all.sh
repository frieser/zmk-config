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

echo '🔧 Initializing west workspace...'
west init -l config
west update
west zephyr-export

echo '🛠️  Building firmware targets...'

python3 << 'PYTHON_SCRIPT'
import yaml
import subprocess
import sys
import shutil
import os

YAML_FILES = ['cornix.yaml', 'totem.yaml', 'forager.yaml']
BASE_FIRMWARE_OUT = '/zmk-config/firmwares'
BUILDS_DIR = '/zmk-config/builds'

if os.path.exists(BASE_FIRMWARE_OUT):
    shutil.rmtree(BASE_FIRMWARE_OUT)

if os.path.exists(BUILDS_DIR):
    shutil.rmtree(BUILDS_DIR)

subprocess.run(['west', 'zephyr-export'], cwd='/zmk-config', check=True)

for yaml_file in YAML_FILES:
    keyboard_name = yaml_file.replace('.yaml', '')
    yaml_path = f'/zmk-config/{yaml_file}'
    
    if not os.path.exists(yaml_path):
        print(f'⚠️  Skipping {yaml_file} (not found)')
        continue
    
    print(f'\n📦 Building {keyboard_name}...')
    
    with open(yaml_path, 'r') as f:
        config = yaml.safe_load(f)
    
    firmware_out = os.path.join(BASE_FIRMWARE_OUT, keyboard_name)
    os.makedirs(firmware_out, exist_ok=True)
    
    for target in config.get('include', []):
        board = target['board']
        artifact = target['artifact-name']
        shield = target.get('shield', '')
        snippet = target.get('snippet', '')
        
        cmd = [
            'west', 'build', '-s', 'zmk/app',
            '-p',
            '-b', board,
            '-d', f'builds/{artifact}'
        ]
        
        if snippet:
            for s in snippet.split():
                cmd.extend(['-S', s])
        
        extra_args = []
        if shield:
            extra_args.append(f'-DSHIELD={shield}')
        
        if 'settings_reset' not in shield:
            extra_args.append('-DZMK_CONFIG=/zmk-config/config')
        
        cmake_args = target.get('cmake-args', '')
        if cmake_args:
            import shlex
            for arg in shlex.split(cmake_args):
                if arg.startswith('-D'):
                    fixed_arg = arg.replace('../../', '/zmk-config/')
                    extra_args.append(fixed_arg)
        
        if extra_args:
            cmd.append('--')
            cmd.extend(extra_args)
        
        print(f'Building: {artifact}')
        print(f'  Board: {board}')
        print(f'  Shield: {shield}')
        
        result = subprocess.run(cmd, cwd='/zmk-config')
        if result.returncode != 0:
            print(f'❌ Failed to build {artifact}')
            sys.exit(1)
        else:
            print(f'✅ Built: {artifact}')
        
        build_path = f'/zmk-config/builds/{artifact}/zephyr/zmk.uf2'
        if os.path.exists(build_path):
            dst = os.path.join(firmware_out, f'{artifact}.uf2')
            shutil.copy2(build_path, dst)
            print(f'✅ Copied: {artifact}.uf2 -> {keyboard_name}/')

print('\n📦 All firmwares collected:')
for keyboard in YAML_FILES:
    name = keyboard.replace('.yaml', '')
    folder = os.path.join(BASE_FIRMWARE_OUT, name)
    if os.path.exists(folder):
        print(f'\n{name}/')
        for f in sorted(os.listdir(folder)):
            print(f'  {f}')
PYTHON_SCRIPT

echo '🎉 All builds completed successfully!'
"
