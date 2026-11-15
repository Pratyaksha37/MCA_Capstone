# Performance and synthesis

Reverified 2026-11-11. Full commands: `./scripts/run_all.sh`.

## Measured workload

`tb_memory_comparison` measures one instruction fetch (address 4, value
0x00100093) and one data read (Harvard address 0, shared address 0x40, value
0x11), requested together. Rising edges are counted until both results complete.
For Harvard, the fetched word and read value are captured at the consuming edge
before the PC's nonblocking increment. Shared responses are captured when their
registered done pulses are observed at the following negedge. The instruction
request is dropped upon completion. Expected counts are asserted only after
measurement; they are not assigned to the counters.

| Organization | Cycles | Operations | Operations/cycle |
|---|---:|---:|---:|
| Harvard | 1 | 2 | 2.00 |
| Shared single port | 2 | 2 | 1.00 |

Shared first serves the instruction and captures the data payload. It serves
that retained payload on the next edge. VCD verification independently confirms
a 10 ns interval between these completion events with the 10 ns test clock.
The speedup ratio is 2/1=2.00 for this pair of operations. It does not establish
a whole-program speedup, sustained streaming throughput, or relative frequency.
The shared requester's completion turnaround can add idle service cycles for
other workloads.

Harvard reads are combinational while shared responses are registered. Counting
the first consuming edge on Harvard normalizes the measured cycle boundary;
a registered Harvard response could still complete both reads on that edge.
No physical SRAM delays are modeled.

## Executed program

`tb_harvard_demo` executes seven instructions, including two stores and two
loads, in seven rising edges (EBREAK is included in retirement). It verifies
x1=5, x2=4, x3=4, RAM[0]=5, RAM[15]=4, halted=1, fault=0. This demonstrates
instruction-controlled data accesses rather than unrelated externally driven
requests. The shared baseline is evaluated using the two-operation workload,
not by executing this whole program.

## Synthesis

Tool: Yosys 0.70+post. Baseline Harvard, shared memory, and demo controller each
run both flows, producing six logs:

```text
RTL:     read_verilog; hierarchy -top <top>; proc; opt; check -assert; stat
Generic: read_verilog; hierarchy -top <top>; proc; opt; memory; opt;
         techmap; opt; check -assert; stat
```

All six structural checks passed with zero problems. The shared RTL flow also
runs `select -assert-count 1 t:$memrd` to enforce one array read port.
`results/synthesis/comparison_table.md` is regenerated from final Yosys statistics
on every successful synthesis run. The generator checks equal 1024-bit storage
and two Harvard versus one shared read port.

| Metric | Harvard baseline | Shared baseline |
|---|---:|---:|
| Arrays | 2 | 1 |
| Storage bits | 1024 | 1024 |
| RTL cells | 59 | 95 |
| Read ports | 2 | 1 |
| Generic cells | 1285 | 2513 |
| Generic multiplexers | 557 | 1219 |
| Generic sequential cells | 542 | 1128 |

The Harvard baseline includes a PC, while shared memory includes an arbiter and
registered responses. The demo-controller resource totals are in `demo_rtl.log`
and `demo_generic.log`; they are not folded into the baseline comparison.

Generic cells are internal Yosys logic, not FPGA LUTs, physical area, power, or
frequency. The shared array remains writable logic across its 1024 bits in the
generic flow; Harvard's instruction ROM can be optimized as constants. These
storage/permission and interface differences limit any area comparison.
The baseline has separate instruction/data range decoders followed by a shared
address selection mux; it should not be described as having only one decoder.

Maximum clock frequency, timing closure, and hardware RAM inference were not
measured. They require a device/library, constraints, memory mapping and a
supported physical timing flow. Power-up initialization is modeled, and no ASIC
power-up guarantee follows from generic synthesis.
