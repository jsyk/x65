/**
 * Simple FIFO Queue, common clock synchronous, small size.
 */
module fifo #(
    parameter BITWIDTH = 8,          // bit-width of one data element
    parameter BITDEPTH = 4          // fifo keeps 2**BITDEPTH elements
)
(
    // Global signals
    input           clk6x,      // 48MHz
    input           resetn,     // sync reset
    // I/O Write port
    input [BITWIDTH-1:0]  wport_i,          // Write Port Data
    input           wenq_i,                 // Enqueue data from the write port now; must not assert when full_o=1
    // I/O read port
    output [BITWIDTH-1:0] rport_o,          // Read port data: valid any time empty_o=0
    input           rdeq_i,                 // Dequeue current data from FIFO
    // Status signals
    output reg      full_o,                 // FIFO is full?
    output reg      empty_o                 // FIFO is empty?
);
    // IMPLEMENTATION

    reg [BITWIDTH-1:0] fifomem [2**BITDEPTH-1:0];
    reg [BITDEPTH-1:0] rptr;
    reg [BITDEPTH-1:0] wptr;

    wire [BITDEPTH-1:0] rptr_next = (rptr + 1);
    wire [BITDEPTH-1:0] wptr_next = (wptr + 1);

    always @(posedge clk6x)
    begin
        if (!resetn)
        begin
            // reset
            rptr <= 0;
            wptr <= 0;
            full_o <= 0;
            empty_o <= 1;
        end else begin
            // Enqueue write data
            if (wenq_i)
            begin
                // store to fifo at the write pointer
                fifomem[wptr] <= wport_i;
                // advance the write pointer
                wptr <= wptr_next;
                if (!rdeq_i)            // special case: enq & deq concurrent -> no state change
                begin
                    // check if full now
                    full_o <= ((wptr_next) == rptr);
                    empty_o <= 0;
                end
            end

            // Dequeue read data
            if (rdeq_i)
            begin
                // advance the read pointer
                rptr <= rptr_next;
                if (!wenq_i)            // special case: enq & deq concurrent -> no state change
                begin
                    // check if empty now
                    empty_o <= (rptr_next) == wptr;
                    full_o <= 0;
                end
            end
        end
    end

    assign rport_o = fifomem[rptr];

endmodule
