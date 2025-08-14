`default_nettype none

module External_Memory_Controller (
    input wire CLK,
    input wire reset,
    
    // Processor interface (same as Data_Memory.v)
    input wire WE,          // Write enable
    input wire [31:0] A,    // Address from processor
    input wire [31:0] WD,   // Write data
    output reg [31:0] RD,   // Read data
    output reg mem_ready,   // Memory operation complete
    
    // SPI interface pins for external memory
    output wire spi_clk,
    output wire spi_mosi,
    input wire spi_miso,
    output wire spi_cs_n
);

    // Internal cache for frequently accessed data
    parameter CACHE_SIZE = 16;  // 16 words cache
    reg [31:0] cache_data [0:CACHE_SIZE-1];
    reg [31:0] cache_addr [0:CACHE_SIZE-1];
    reg cache_valid [0:CACHE_SIZE-1];
    reg [3:0] cache_lru;  // Simple LRU counter
    
    // Memory controller state machine
    parameter IDLE = 3'b000;
    parameter CHECK_CACHE = 3'b001;
    parameter START_SPI = 3'b010;
    parameter WAIT_SPI = 3'b011;
    parameter UPDATE_CACHE = 3'b100;
    parameter COMPLETE = 3'b101;

    reg [2:0] current_state, next_state;
    
    // SPI Controller interface
    wire spi_data_ready;
    reg spi_start;
    wire [31:0] spi_read_data;
    reg [31:0] spi_address;
    reg [31:0] spi_write_data;
    reg spi_write_enable;
    
    // Internal registers
    reg [31:0] current_address;
    reg [31:0] current_write_data;
    reg current_we;
    reg cache_hit;
    reg [3:0] cache_hit_index;
    reg operation_pending;
    
    // Initialize cache and registers
    integer i;
    initial begin
        current_state = IDLE;
        mem_ready = 1'b1;  // Ready initially
        RD = 32'b0;
        spi_start = 1'b0;
        spi_address = 32'b0;
        spi_write_data = 32'b0;
        spi_write_enable = 1'b0;
        current_address = 32'b0;
        current_write_data = 32'b0;
        current_we = 1'b0;
        cache_hit = 1'b0;
        cache_hit_index = 4'b0;
        cache_lru = 4'b0;
        operation_pending = 1'b0;
        
        // Initialize cache
        cache_data[0] = 32'b0; cache_data[1] = 32'b0; cache_data[2] = 32'b0; cache_data[3] = 32'b0;
    cache_data[4] = 32'b0; cache_data[5] = 32'b0; cache_data[6] = 32'b0; cache_data[7] = 32'b0;
    cache_data[8] = 32'b0; cache_data[9] = 32'b0; cache_data[10] = 32'b0; cache_data[11] = 32'b0;
    cache_data[12] = 32'b0; cache_data[13] = 32'b0; cache_data[14] = 32'b0; cache_data[15] = 32'b0;
    
    cache_addr[0] = 32'hFFFFFFFF; cache_addr[1] = 32'hFFFFFFFF; cache_addr[2] = 32'hFFFFFFFF; cache_addr[3] = 32'hFFFFFFFF;
    cache_addr[4] = 32'hFFFFFFFF; cache_addr[5] = 32'hFFFFFFFF; cache_addr[6] = 32'hFFFFFFFF; cache_addr[7] = 32'hFFFFFFFF;
    cache_addr[8] = 32'hFFFFFFFF; cache_addr[9] = 32'hFFFFFFFF; cache_addr[10] = 32'hFFFFFFFF; cache_addr[11] = 32'hFFFFFFFF;
    cache_addr[12] = 32'hFFFFFFFF; cache_addr[13] = 32'hFFFFFFFF; cache_addr[14] = 32'hFFFFFFFF; cache_addr[15] = 32'hFFFFFFFF;
    
    cache_valid[0] = 1'b0; cache_valid[1] = 1'b0; cache_valid[2] = 1'b0; cache_valid[3] = 1'b0;
    cache_valid[4] = 1'b0; cache_valid[5] = 1'b0; cache_valid[6] = 1'b0; cache_valid[7] = 1'b0;
    cache_valid[8] = 1'b0; cache_valid[9] = 1'b0; cache_valid[10] = 1'b0; cache_valid[11] = 1'b0;
    cache_valid[12] = 1'b0; cache_valid[13] = 1'b0; cache_valid[14] = 1'b0; cache_valid[15] = 1'b0;
end
    
    // Instantiate SPI Controller
    SPI_Controller spi_ctrl (
        .CLK(CLK),
        .reset(reset),
        .WE(spi_write_enable),
        .A(spi_address),
        .WD(spi_write_data),
        .RD(spi_read_data),
        .data_ready(spi_data_ready),
        .start_transaction(spi_start),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n)
    );
    
    // Cache lookup logic
    always @(*) begin
    cache_hit = 1'b0;
    cache_hit_index = 4'b0;
    
    // Unrolled cache lookup for better synthesis
    if (cache_valid[0] && (cache_addr[0] == current_address)) begin
        cache_hit = 1'b1; cache_hit_index = 4'd0;
    end else if (cache_valid[1] && (cache_addr[1] == current_address)) begin
        cache_hit = 1'b1; cache_hit_index = 4'd1;
    end else if (cache_valid[2] && (cache_addr[2] == current_address)) begin
        cache_hit = 1'b1; cache_hit_index = 4'd2;
    end else if (cache_valid[3] && (cache_addr[3] == current_address)) begin
        cache_hit = 1'b1; cache_hit_index = 4'd3;
    end else if (cache_valid[4] && (cache_addr[4] == current_address)) begin
        cache_hit = 1'b1; cache_hit_index = 4'd4;
    end else if (cache_valid[5] && (cache_addr[5] == current_address)) begin
        cache_hit = 1'b1; cache_hit_index = 4'd5;
    end else if (cache_valid[6] && (cache_addr[6] == current_address)) begin
        cache_hit = 1'b1; cache_hit_index = 4'd6;
    end else if (cache_valid[7] && (cache_addr[7] == current_address)) begin
        cache_hit = 1'b1; cache_hit_index = 4'd7;
    end else if (cache_valid[8] && (cache_addr[8] == current_address)) begin
        cache_hit = 1'b1; cache_hit_index = 4'd8;
    end else if (cache_valid[9] && (cache_addr[9] == current_address)) begin
        cache_hit = 1'b1; cache_hit_index = 4'd9;
    end else if (cache_valid[10] && (cache_addr[10] == current_address)) begin
        cache_hit = 1'b1; cache_hit_index = 4'd10;
    end else if (cache_valid[11] && (cache_addr[11] == current_address)) begin
        cache_hit = 1'b1; cache_hit_index = 4'd11;
    end else if (cache_valid[12] && (cache_addr[12] == current_address)) begin
        cache_hit = 1'b1; cache_hit_index = 4'd12;
    end else if (cache_valid[13] && (cache_addr[13] == current_address)) begin
        cache_hit = 1'b1; cache_hit_index = 4'd13;
    end else if (cache_valid[14] && (cache_addr[14] == current_address)) begin
        cache_hit = 1'b1; cache_hit_index = 4'd14;
    end else if (cache_valid[15] && (cache_addr[15] == current_address)) begin
        cache_hit = 1'b1; cache_hit_index = 4'd15;
    end
end
    
    // Main state machine
    always @(posedge CLK or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
            mem_ready <= 1'b1;
            RD <= 32'b0;
            spi_start <= 1'b0;
            operation_pending <= 1'b0;
            cache_lru <= 4'b0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    mem_ready <= 1'b1;
                    spi_start <= 1'b0;
                    
                    // Capture new memory request
                    if ((WE || !mem_ready) && !operation_pending) begin
                        current_address <= A;
                        current_write_data <= WD;
                        current_we <= WE;
                        operation_pending <= 1'b1;
                        mem_ready <= 1'b0;
                    end
                end
                
                CHECK_CACHE: begin
                    if (cache_hit && !current_we) begin
                        // Cache hit for read
                        RD <= cache_data[cache_hit_index];
                        mem_ready <= 1'b1;
                        operation_pending <= 1'b0;
                    end else begin
                        // Cache miss or write operation
                        mem_ready <= 1'b0;
                    end
                end
                
                START_SPI: begin
                    spi_address <= current_address;
                    spi_write_data <= current_write_data;
                    spi_write_enable <= current_we;
                    spi_start <= 1'b1;
                end
                
                WAIT_SPI: begin
                    spi_start <= 1'b0;
                    if (spi_data_ready) begin
                        if (!current_we) begin
                            RD <= spi_read_data;
                        end
                    end
                end
                
                UPDATE_CACHE: begin
                    if (!current_we) begin
                        // Update cache with read data
                        cache_data[cache_lru] <= spi_read_data;
                        cache_addr[cache_lru] <= current_address;
                        cache_valid[cache_lru] <= 1'b1;
                        cache_lru <= cache_lru + 1;
                        if (cache_lru >= CACHE_SIZE-1) 
                            cache_lru <= 4'b0;
                    end else begin
                        // Invalidate cache entry for write
                        for (i = 0; i < CACHE_SIZE; i = i + 1) begin
                            if (cache_valid[i] && (cache_addr[i] == current_address)) begin
                                cache_valid[i] <= 1'b0;
                            end
                        end
                    end
                end
                
                COMPLETE: begin
                    mem_ready <= 1'b1;
                    operation_pending <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (operation_pending)
                    next_state = CHECK_CACHE;
            end
            
            CHECK_CACHE: begin
                if (cache_hit && !current_we)
                    next_state = COMPLETE;
                else
                    next_state = START_SPI;
            end
            
            START_SPI: begin
                next_state = WAIT_SPI;
            end
            
            WAIT_SPI: begin
                if (spi_data_ready)
                    next_state = UPDATE_CACHE;
            end
            
            UPDATE_CACHE: begin
                next_state = COMPLETE;
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule