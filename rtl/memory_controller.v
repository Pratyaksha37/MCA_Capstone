`timescale 1ns/1ps
// Combinational read/write controller for the Harvard data path.
//
// Policy:
//   * No request                -> no read, no write, no error.
//   * Request with invalid addr -> access_error, no read, no write.
//   * Read request only         -> read_enable.
//   * Write request only        -> write_enable.
//   * Read and write together   -> write_enable only (write priority);
//                                  the read is rejected and read_valid stays low.
//
// The write itself is performed by data_memory on the next rising clock edge.
module memory_controller (
    input  wire read_request,
    input  wire write_request,
    input  wire address_valid,
    output reg  read_enable,
    output reg  write_enable,
    output reg  access_error
);

    always @* begin
        read_enable  = 1'b0;
        write_enable = 1'b0;
        access_error = 1'b0;

        if (read_request || write_request) begin
            if (!address_valid) begin
                access_error = 1'b1;
            end else if (write_request) begin
                write_enable = 1'b1;      // write wins if both are requested
            end else begin
                read_enable = 1'b1;
            end
        end
    end

endmodule
