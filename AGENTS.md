<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# AGENTS.md for ZMK Config Repository

## Build Commands
- **Para probar todas las funcionalidades y compilar todos los firmwares de los teclados ZMK**: `bash build-all.sh`
  - Este es el comando principal que compila todas las variantes de teclado usando podman y west
  - **IMPORTANTE**: Este script tarda varios minutos en completarse
  - Debe ejecutarse en background de forma asincrónica (usando tmux/interactive_bash o herramientas de background)
  - Comprobar el estado de forma asincrónica durante la ejecución
  - **SINCRONIZACIÓN CRÍTICA**: El script `build-all.sh` y el archivo `build.yaml` deben estar sincronizados
    - Ambos deben compilar exactamente las mismas configuraciones de teclados
    - `build.yaml` se usa en GitHub Actions
    - `build-all.sh` lee el `build.yaml` y replica las mismas compilaciones localmente
    - Cualquier cambio en las configuraciones debe reflejarse en ambos archivos
  - **ESPERA OBLIGATORIA**: Al ejecutar `build-all.sh` o cualquier comando de compilación, DEBES esperar a que termine completamente y devuelva el control (prompt) antes de considerar la tarea como válida o terminada.
    - El proceso puede tardar varios minutos (10-15+ minutos).
    - No asumas que ha funcionado hasta ver el mensaje de éxito final o el código de salida 0.
    - Si se ejecuta en background, usa `wait` o monitorea activamente hasta la finalización.
- Single board build: `west build -p -s zmk/app -b <board> -d builds/<name> -- -DSHIELD="<shields>" -DKEYMAP_FILE=config/<keymap>`

## Lint/Test Commands
- No automated tests; manual testing required on hardware
- Lint DTS: Use `dtc -I dts -O dtb <file>.dtsi` to check syntax
- Run single "test": Flash firmware and verify keymap on keyboard

## Code Style Guidelines
- **File Structure**: Use .dtsi includes for behaviors, layers, macros; .keymap for bindings
- **Naming**: snake_case for behavior names, macros, layers; UPPER_CASE for defines
- **Formatting**: 4-space indentation; align bindings in columns; use < > for key codes
- **Imports**: #include relative paths; order: behaviors.dtsi, layers.dtsi, etc.
- **Types**: Use compatible strings like "zmk,behavior-hold-tap"; #binding-cells as needed
- **Error Handling**: Validate DTS with dtc; test behaviors on actual hardware
- **Comments**: Use // for single-line; document complex behaviors/macros
- **Keymaps**: Group by layers; use LAYER_FROMXX macros for readability
- **Conventions**: Follow ZMK docs; use positional hold-taps for home rows; avoid magic numbers