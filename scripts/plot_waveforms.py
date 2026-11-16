#!/usr/bin/env python3
"""Optional matplotlib render of actual VCD signals; run after make test."""
import os
import tempfile
os.environ.setdefault('XDG_CACHE_HOME', tempfile.mkdtemp(prefix='harvard-cache-'))
os.environ.setdefault('MPLCONFIGDIR', tempfile.mkdtemp(prefix='harvard-mpl-'))
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from verify_waveforms import ROOT, read_vcd, value

fig, axes = plt.subplots(2, 1, figsize=(12, 8), layout='constrained')
for ax, filename, prefix, signals, title in [
    (axes[0], 'tb_memory_comparison', 'tb_memory_comparison.',
     ['clk', 'h_data_read_req', 'h_instr_valid', 'h_data_valid', 's_instr_req',
      's_data_req', 's_instr_done', 's_pending_data', 's_data_done'],
     'Measured pair: Harvard 1 cycle; shared port 2 cycles'),
    (axes[1], 'tb_harvard_demo', 'tb_harvard_demo.',
     ['clk', 'reset', 'data_write', 'data_read', 'halted', 'fault'],
     'Executed program: store 5, load 5, subtract 1, store/load 4, halt')]:
    names, samples = read_vcd(ROOT / 'results/waveforms' / (filename + '.vcd'))
    times = [t / 1000 for t, _ in samples]  # all benches use 1 ps VCD timebase
    for index, signal in enumerate(signals):
        offset = len(signals) - 1 - index
        ys = [offset + .65 * (value(names, s, prefix + signal) or 0) for _, s in samples]
        ax.step(times, ys, where='post', linewidth=1.5)
    ax.set_yticks(range(len(signals)), signals[::-1])
    ax.set_xlabel('Simulation time (ns)')
    ax.set_title(title, loc='left')
    ax.grid(axis='x', alpha=.25)
    ax.spines[['top', 'right', 'left']].set_visible(False)
    ax.set_xlim(0, min(times[-1], 120) if filename == 'tb_harvard_demo' else times[-1])
fig.savefig(ROOT / 'results/waveforms/verified_timing.png', dpi=160)
print('Rendered results/waveforms/verified_timing.png from VCD transitions')
