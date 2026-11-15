# Testing and verification

Verified 2026-11-11 with Icarus Verilog 13.0. Run `make test` from the project
root. Testbenches use four-state mismatch checks / strict Boolean checks and
`$fatal` on failures. The runner requires simulation success, a PASS marker,
a nonempty VCD for every test, the performance report, and successful VCD checks.

| Testbench | Coverage | Checks | Result |
|---|---|---:|---|
| tb_program_counter | Synchronous reset, increments, reset restart | 8 | PASS |
| tb_instruction_memory | All 16 words, alignment, range, high-address alias | 38 | PASS |
| tb_data_memory | Combinational reads, write-edge timing, persistence, invalid write | 18 | PASS |
| tb_harvard_memory_system | Integration, concurrent access, invalid reads, write priority | 36 | PASS |
| tb_shared_port_memory | Region boundaries, arbitration, retained request, writes | 40 | PASS |
| tb_memory_comparison | Actual returned values and measured 1 vs 2 cycles | 14 | PASS |
| tb_harvard_demo | Seven executed instructions, all fetched words, data results, x0 protection, illegal instruction, bad-address faults, halt, reset | 36 | PASS |
| tb_memory_edges | Full control truth table, 256 seeded scoreboard transactions, invalid shared addresses, captured-write payload, synchronous completion turnaround, reset abort, data progress | 825 | PASS |
| Total | Eight testbenches | 1015 | PASS |

Logs and the regression summary are generated in `results/simulation/`.
Scoreboard seed is 4127 for reproducibility. Memory contents are checked against
an independent expected-state array; invalid writes must preserve that state.
The test also checks all sixteen words after the transaction sequence.

`verify_waveforms.py` parses timestamped VCD values and asserts:

- PC=4, instruction=0x00100093 and data=0x11 valid together on Harvard.
- Shared instruction completion with pending data, followed 10 ns later by data completion.
- No overlapping instruction/data shared service signals.
- Measured counters are Harvard=1 and shared=2.
- The demo halts after seven retired instructions with result 4.

The report is `results/simulation/waveform_verification.txt`. Eight raw VCD files
are provided. `python3 scripts/plot_waveforms.py` renders the comparison and
program control signals to `results/waveforms/verified_timing.png`; this plot
was visually inspected. GTKWave was not used.

These are simulation and structural checks, not exhaustive formal verification.
The demo test also executes an attempted x0 write, an unsupported instruction,
an unaligned load, and an out-of-range store. It does not exhaust every illegal encoding.
There is no gate-level timing simulation or FPGA hardware test.
