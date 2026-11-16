#!/usr/bin/env python3
"""Read generated VCD transitions, assert architectural evidence, write report."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read_vcd(path):
    scopes, names, state, samples = [], {}, {}, []
    time = 0
    with path.open() as stream:
        for line in stream:
            parts = line.split()
            if not parts:
                continue
            if parts[0] == '$scope':
                scopes.append(parts[2])
            elif parts[0] == '$upscope':
                scopes.pop()
            elif parts[0] == '$var':
                names['.'.join(scopes + [parts[4]])] = parts[3]
            elif line.startswith('#'):
                samples.append((time, state.copy()))
                time = int(line[1:])
            elif line[0] in '01xz':
                state[line[1:].strip()] = line[0]
            elif line[0] in 'bB':
                state[parts[1]] = parts[0][1:]
    samples.append((time, state.copy()))
    return names, samples


def value(names, state, name):
    bits = state.get(names[name], 'x')
    return None if any(c in bits for c in 'xzXZ') else int(bits, 2)


def main():
    folder = ROOT / 'results/waveforms'
    files = sorted(folder.glob('*.vcd'))
    assert len(files) >= 8, 'Missing waveform files'
    for path in files:
        names, samples = read_vcd(path)
        assert names and len(samples) > 2, f'No transitions in {path}'
    names, samples = read_vcd(folder / 'tb_memory_comparison.vcd')
    prefix = 'tb_memory_comparison.'
    def v(state, key):
        return value(names, state, prefix + key)
    assert any(v(s, 'h_pc') == 4 and v(s, 'h_instr') == 0x00100093
               and v(s, 'h_instr_valid') == 1 and v(s, 'h_data_valid') == 1
               and v(s, 'h_data_rdata') == 0x11 for _, s in samples)
    first = [t for t, s in samples if v(s, 's_instr_done') == 1
             and v(s, 's_pending_data') == 1]
    second = [t for t, s in samples if v(s, 's_data_done') == 1
              and v(s, 's_data_rdata') == 0x11]
    assert first and second and min(second) - min(first) == 10000, 'Expected one 10 ns serialization delay'
    assert not any(v(s, 's_service_instr') == 1 and v(s, 's_service_data') == 1
                   for _, s in samples), 'Shared port served twice'
    assert v(samples[-1][1], 'harvard_cycles') == 1
    assert v(samples[-1][1], 'shared_cycles') == 2
    names, samples = read_vcd(folder / 'tb_harvard_demo.vcd')
    assert any(value(names, s, 'tb_harvard_demo.halted') == 1
               and value(names, s, 'tb_harvard_demo.retired') == 7
               and value(names, s, 'tb_harvard_demo.result') == 4 for _, s in samples)
    report = ('Waveform verification: PASS\n'
              f'{len(files)} VCD files contain signal declarations and timestamped samples.\n'
              'Harvard: PC=4, instruction=00100093 and data=00000011 valid together.\n'
              'Shared: instruction completion/pending precedes data completion by 10 ns.\n'
              'Shared instruction/data service signals never overlap.\n'
              'Measured cycle counters: Harvard=1, shared=2.\n'
              'Program: halted with 7 retired instructions and x3=4.\n')
    (ROOT / 'results/simulation/waveform_verification.txt').write_text(report)
    print(report, end='')


if __name__ == '__main__':
    main()
