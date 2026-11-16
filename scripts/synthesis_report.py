#!/usr/bin/env python3
"""Generate resource comparison from final Yosys stat blocks, never constants."""
from pathlib import Path
import re

folder = Path(__file__).resolve().parents[1] / 'results/synthesis'


def stats(stem):
    log = (folder / (stem + '.log')).read_text()
    block = re.split(r'^=== .* ===$', log, flags=re.M)[-1]
    def count(label):
        match = re.search(r'^\s*(\d+|-)\s+' + re.escape(label) + r'\s*$', block, re.M)
        return int(match[1]) if match and match[1] != '-' else 0
    cells = {name: int(n) for n, name in re.findall(r'^\s*(\d+)\s+(\$\S+)\s*$', block, re.M)}
    return count, cells


hr, _ = stats('harvard_rtl')
sr, _ = stats('shared_rtl')
hg, hc = stats('harvard_generic')
sg, sc = stats('shared_generic')
rows = [('Memory arrays (RTL)', hr('memories'), sr('memories')),
        ('Memory bits (RTL)', hr('memory bits'), sr('memory bits')),
        ('RTL cells', hr('cells'), sr('cells')),
        ('Read ports (RTL)', hr('$memrd'), sr('$memrd')),
        ('Total generic cells', hg('cells'), sg('cells'))]
for label, cell in [('AND cells', '$_AND_'), ('OR cells', '$_OR_'),
                    ('NOT cells', '$_NOT_'), ('XOR cells', '$_XOR_'), ('Multiplexers', '$_MUX_')]:
    rows.append((label, hc.get(cell, 0), sc.get(cell, 0)))
rows.append(('Sequential cells', sum(n for c, n in hc.items() if 'DFF' in c),
             sum(n for c, n in sc.items() if 'DFF' in c)))
assert hr('memory bits') == sr('memory bits') == 1024
assert hr('$memrd') == 2 and sr('$memrd') == 1
text = '# Synthesis comparison (generated from current logs)\n\n'
text += '| Metric | Harvard | Shared single port |\n|---|---:|---:|\n'
text += ''.join(f'| {label} | {h} | {s} |\n' for label, h, s in rows)
text += '\nGeneric cells are not FPGA LUTs, physical area, power, or frequency.\n'
text += 'No target timing analysis was performed. Demo-controller synthesis logs are separate.\n'
(folder / 'comparison_table.md').write_text(text)
print('Resource report: PASS (equal storage; Harvard 2 read ports, shared 1)')
