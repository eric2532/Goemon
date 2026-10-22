"""Run isolated Godot army tests and retain full diagnostics with build artifacts."""
import pathlib
import re
import subprocess
import sys
import time

PROJECT = pathlib.Path(__file__).resolve().parents[2]
LOGS = pathlib.Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Large Army Rebuild/Tests')
GODOT = '/Applications/Godot.app/Contents/MacOS/Godot'

def runtime_errors(output):
    # Known engine shutdown leaks are tracked separately. Non-fatal engine
    # errors during a test (including typed-array validation) must fail it.
    return [line for line in output.splitlines() if 'ERROR:' in line and not re.match(
        r'ERROR: (\d+ RID allocations|\d+ resources still in use|Pages in use exist at exit)', line)]

def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    names = sys.argv[1:] or [p.stem for p in sorted((PROJECT/'tests/forest-shrine').glob('army_*_test.gd'))]
    failed = []
    for name in names:
        path = PROJECT/'tests/forest-shrine'/f'{name}.gd'
        if not path.is_file():
            print(f'FAIL missing test {name}', flush=True)
            failed.append(name)
            continue
        log = LOGS/f'{name}.log'
        with log.open('w') as stream:
            process = subprocess.Popen([GODOT, '--headless', '--path', str(PROJECT), '--script', str(path)],
                                       stdout=stream, stderr=subprocess.STDOUT, text=True)
            started = time.monotonic()
            while process.poll() is None:
                output = log.read_text(errors='replace')
                if 'SCRIPT ERROR' in output or time.monotonic()-started>180:
                    process.terminate()
                    try:
                        process.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                    if time.monotonic()-started>180:
                        stream.write('\nFAIL: 180-second timeout\n')
                    break
                time.sleep(.05)
            code = process.returncode
        output = log.read_text(errors='replace')
        errors = runtime_errors(output)
        bad = code != 0 or bool(errors) or 'FAIL:' in output or ('_RESULT' not in output and not any('checks, 0 failures' in line for line in output.splitlines()))
        if bad:
            failed.append(name)
        print(('FAIL ' if bad else 'PASS ') + name, flush=True)
        displayed=set()
        for line in output.splitlines():
            if '_RESULT' in line or 'FAIL:' in line or line in errors:
                if line not in displayed and len(displayed)<20:
                    print('  ' + line, flush=True)
                    displayed.add(line)
    print(f'LARGE_ARMY_SUITE_RESULT tests={len(names)} failures={len(failed)}', flush=True)
    return bool(failed)

if __name__ == '__main__':
    raise SystemExit(main())
