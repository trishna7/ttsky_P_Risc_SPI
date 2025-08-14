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
    typedef enum logic [2:0] {
        IDLE,
        CHECK_CACHE,
        START_SPI,
        WAIT_SPI,
        UPDATE_CACHE,
        COMPLETE
    } mem_state_t;
    
    mem_state_t current_state, next_state;
    
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
        for (i = 0; i < CACHE_SIZE; i = i + 1) begin
            cache_data[i] = 32'b0;
            cache_addr[i] = 32'hFFFFFFFF; // Invalid address
            cache_valid[i] = 1'b0;
        end
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
        
        for (i = 0; i < CACHE_SIZE; i = i + 1) begin
            if (cache_valid[i] && (cache_addr[i] == current_address)) begin
                cache_hit = 1'b1;
                cache_hit_index = i[3:0];
            end
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