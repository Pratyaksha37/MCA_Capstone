# Microarchitecture and Timing

## 1. Clock and reset

- All sequential logic uses the rising edge of `clk`.
- `reset` is active high and synchronous.
- The Harvard PC and the shared-memory arbitration registers have reset behavior.
- Memory arrays are initialized at time zero and are not cleared by reset.

Testbenches use a 10 ns clock period (5 ns high, 5 ns low), but the RTL itself
contains no clock frequency assumptions.

## 2. Program counter state transition

| Reset | Next PC |
|---:|---:|
| 1 | `0x00000000` |
| 0 | `PC + 4` |

The PC is a 32-bit byte address. Two low bits remain zero because every increment
is four. The Verilog is:

```verilog
always @(posedge clk) begin
    if (reset)
        pc <= 32'd0;
    else
        pc <= pc + 32'd4;
end
```

The increment is 4 rather than 1 because instruction memory is byte-addressed
but word-organized. A 16-word memory uses `PC[5:2]` as the word index.

## 3. Instruction fetch timing

`instruction_fetch` contains the PC and instruction memory. At any stable PC
value, the instruction word and `instruction_valid` are combinational outputs.
The sequence in a test is:

1. Apply reset for at least one rising edge.
2. Release reset.
3. Observe PC = 0 and instruction word 0 before the first increment.
4. On each rising edge the PC advances: 4, 8, 12, ...
5. The instruction output follows the new PC after the edge.

The testbench checks PC and instruction words at negedges, after the nonblocking
updates from the preceding rising edge have settled.

## 4. Harvard data read

`data_memory` implements a combinational read:

```verilog
assign read_data = (read_enable && valid) ? mem[word_index] : 32'h00000000;
```

The controller asserts `read_enable` only for a valid request. Therefore
`data_read_valid` and `data_read_data` are valid in the same cycle in which the
request and address are applied. No clock edge is required to return the read
data; the next rising edge only marks the cycle boundary and may advance the PC.

This is a simple combinational-read model. It is not a synchronous SRAM timing
model with a registered read latency.

## 5. Harvard data write

The write path is edge-triggered:

```verilog
always @(posedge clk) begin
    if (write_enable && valid)
        mem[word_index] <= write_data;
end
```

`data_write_enable` is the controller's write-enable output. A testbench asserts
the write request before a rising edge and holds it through that edge. A read
performed in the same cycle before the edge returns the **old** word; a read
after the edge returns the new word.

### Write/read conflict

If `data_read_req` and `data_write_req` are both high with a valid address:

- `data_write_enable = 1`
- `data_read_valid = 0`
- `access_error = 0`

The write wins. This is deterministic and is verified by
`tb_harvard_memory_system`.

## 6. Invalid addresses

The address decoder rejects:

- unaligned addresses (`address[1:0] != 00`)
- addresses outside `0x00`-`0x3C`

For a rejected data request, the controller asserts `access_error` and suppresses
both read and write enables. Instruction memory returns zero and
`instruction_valid = 0`. The tests explicitly check these cases, so an invalid
access does not silently select a word.

## 7. Shared-memory request handling

The shared design has a small amount of sequential state:

| State | Meaning |
|---|---|
| `pending_valid` | A data request was captured while an instruction was served |
| `pending_addr` | Captured data byte address |
| `pending_write` | Captured read/write flag |
| `pending_wdata` | Captured write data |
| `instr_rdata`, `instr_done` | Registered instruction response and completion pulse |
| `data_rdata`, `data_done` | Registered data response and completion pulse |

The arbitration expressions are combinational:

```text
service_instr = !reset && instr_req && !instr_done && instr_addr_valid && !pending_valid
service_data  = !reset && (pending_valid ||
                (!service_instr && data_req && !data_done && data_addr_valid))
```

### Service sequence

| Current situation | What is served at the next edge | Completion |
|---|---|---|
| No request | Nothing | Both done signals low |
| Instruction only | Instruction | `instr_done` pulse next cycle |
| Data only | Data read or write | `data_done` pulse next cycle |
| Both arrive together | Instruction first; data captured | `instr_done` first, then `data_done` |
| Data pending, new instruction arrives | Pending data is promoted | `data_done`; instruction waits |
| Reset | Pending state and done pulses cleared | Memory contents unchanged |

The anti-starvation rule is the `pending_valid` term in `service_instr`: while
data is pending, a new instruction request cannot keep the port. In the test, the
instruction request is deliberately left asserted during the data service cycle,
and the data request still completes.

### Registered completion

`instr_done` and `data_done` are set by nonblocking assignments on a rising edge
and cleared on the following rising edge. They are therefore one-cycle pulses.
The corresponding read data register is updated on the same edge, so the data is
valid while the done pulse is high.

The testbench samples at negedges, halfway between rising edges, to avoid any
race between the DUT's nonblocking updates and the testbench's checks.

## 8. Harvard versus shared timing for the measured workload

The measured workload requests one instruction fetch and one data read at the
same time.

### Harvard

- Instruction memory and data memory are separate.
- Both accesses are combinational and are valid in the same request cycle.
- Completion cycle count: **1**.

### Shared single port

- Cycle 1: instruction is served; data is captured as pending.
- Cycle 2: pending data is served.
- Completion cycle count: **2**.

The cycle count is not a hard-coded constant. `tb_memory_comparison` observes the
actual `instruction_valid`, `data_read_valid`, `instr_done`, `data_done`, and
`pending_data` signals and counts the rising edges until both results are
complete. It verifies the returned instruction and data values.

## 9. Design notes

- There is no state machine in the Harvard design; the PC is the only sequential
  state in the instruction path and data writes are simple edge-triggered updates.
- The shared baseline has a small pending-request state, not a general-purpose
  bus FSM.
- No latches are intended. The controller assigns all outputs in every path of
  its combinational `always @*` block. Yosys `check` reported zero structural
  problems for both designs.

## 10. Executable controller and completion turnaround

`harvard_demo` has its own PC/register state and selects `DEMO_PROGRAM=1`
in instruction memory. It consumes ADDI/LW/SW/EBREAK at rising edges, stops on
halt/fault, and suppresses requests during reset/halt/fault. This controller is
separate from the continuously incrementing baseline fetch demonstration.

The shared array has one address mux before one read expression. Each
requester's done cycle blocks further service for that requester, permitting
a synchronous caller to consume done and deassert req without replay. A new
request may be accepted after done clears. Invalid addresses are unacknowledged.
