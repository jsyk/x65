/* Copyright (c) 2023 Jaroslav Sykora.
 * Terms and conditions of the MIT License apply; see the file LICENSE in top-level directory. */
/**
 * Trace buffer, common clock synchronous, small size.
 */
module tracebuf #(
    parameter BITWIDTH = 8,          // bit-width of one data element
    parameter BITDEPTH = 4          // buffer keeps 2**BITDEPTH elements
)
(
    // Global signals
    input           clk,                    // 48MHz
    input           resetn,                 // sync reset
    // I/O Write port
    input [BITWIDTH-1:0]  wport_i,          // Write Port Data
    input           wenq_i,                 // Enqueue data from the write port now; must not assert when full_o=1
    // I/O read port
    output [BITWIDTH-1:0] rport_o,          // Read port data: valid any time empty_o=0
    input           rdeq_i,                 // Dequeue current data from FIFO
    input           clear_i,                // Clear the buffer (reset)
    // Status signals
    output reg      full_o,                 // FIFO is full?
    output reg      empty_o,                // FIFO is empty?
    output reg [BITDEPTH:0]   count_o       // count of elements in the FIFO now; mind the width of the reg!
);
    // IMPLEMENTATION

    reg [BITWIDTH-1:0] tracemem [2**BITDEPTH-1:0];          // infer a block ram
    reg [BITDEPTH-1:0] rptr;                // current read and write pointers
    reg [BITDEPTH-1:0] wptr;

    wire [BITDEPTH-1:0] rptr_next = (rptr + 1);     // next read and write pointers, if enq or deq.
    wire [BITDEPTH-1:0] wptr_next = (wptr + 1);

    always @(posedge clk)
    begin
        if (!resetn || clear_i)
        begin
            // reset or clear
            rptr <= 0;
            wptr <= 0;
            full_o <= 0;
            empty_o <= 1;
            count_o <= 0;
        end else begin
            // Enqueue write data
            if (wenq_i)
            begin
                // store to fifo at the write pointer
                tracemem[wptr] <= wport_i;
                // advance the write pointer
                wptr <= wptr_next;

                // if (!rdeq_i)            // special case: enq & deq concurrent -> no state change
                // begin
                //     // not the special case (just enq): 

                // Trace buffer handles overflows by gracefully overwriting the oldest item - ring buffer.
                // Were we already full before this append?
                if (full_o)
                begin
                    // yes, we had to overwrite the oldest trace item -> must advance the read pointer as well
                    rptr <= rptr_next;
                    // don't change the count - it is already at the top (saturating)
                end else begin
                    // no -> 
                    //       check if full now:
                    full_o <= ((wptr_next) == rptr);
                    // definitely not empty now
                    empty_o <= 0;
                    // one more item
                    count_o <= count_o + 1;
                end
            end

            // Dequeue read data
            if (rdeq_i)
            begin
                // advance the read pointer
                rptr <= rptr_next;

                // if (!wenq_i)            // special case: enq & deq concurrent -> no state change
                // begin
                    // not the special case (just deq):

                //   check if empty now?
                empty_o <= (rptr_next) == wptr;
                // definitely not full now!
                full_o <= 0;
                // one less item
                count_o <= count_o - 1;
                // end
            end
        end
    end

    assign rport_o = tracemem[rptr];

endmodule
