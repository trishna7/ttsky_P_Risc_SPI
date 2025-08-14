`default_nettype none

module Control_unit (
    //input
    input [6:0] opcode,
    input [4:0] Des_Reg,

    //output reg pc_src,
    output reg RegWriteD,
    output reg [2:0] ImmSrcD,
    output reg ALUSrcD,
    output reg [1:0] ResultSrcD,
    output reg MemWriteD,
    output reg JumpD,
    output reg BranchD,
    output reg [1:0] ALUOp,
    output reg JalSrcD,
    output reg USrcD,
    output reg UOControlD

);


always @(*) begin
    // Default values to handle invalid opcodes
            RegWriteD  = 1'b0;
            ImmSrcD    = 3'b000;
            ALUSrcD    = 1'b0;
            ResultSrcD = 2'b00;
            MemWriteD  = 1'b0;
            BranchD    = 1'b0;
            ALUOp      = 2'b00;
            JumpD      = 1'b0;
            JalSrcD    = 1'b0;
            USrcD      = 1'b0;
            UOControlD = 1'b0;
    
    case (opcode)
        7'b0110011 : begin //R-type
            RegWriteD = 1'b1;
            ALUSrcD = 0;
            MemWriteD = 0;
            ResultSrcD = 2'b00;
            BranchD = 0;
            ALUOp = 2'b10;
            JumpD = 0;
            // JalSrcD = 0;
            // USrcD = 0;
            // UOControlD = 0;
        end

        7'b0010011 : begin //I-type
            RegWriteD = (Des_Reg != 5'b0) ? 1 : 0;  // Don't write if rd=x0
            ImmSrcD = 3'b000;
            ALUSrcD = 1'b1;
            MemWriteD = 0;
            ResultSrcD = 2'b00;
            BranchD = 0;
            ALUOp = 2'b10;
            JumpD = 0;
            // JalSrcD = 0;
            USrcD = 0;
            // UOControlD = 0;
        end

        7'b0000011 : begin // Load 
            RegWriteD = 1'b1;
            ImmSrcD = 3'b000;
            ALUSrcD = 1'b1;
            MemWriteD = 0;
            ResultSrcD = 2'b01;
            BranchD = 0;
            ALUOp = 2'b00;
            JumpD = 0;
            // JalSrcD = 0;
            USrcD = 0;

        end

        7'b0100011 : begin // store
            RegWriteD = 1'b0;
            ImmSrcD = 3'b001;
            ALUSrcD = 1;
            MemWriteD = 1;
            BranchD = 0;
            ALUOp = 2'b00;
            JumpD = 0;
            // JalSrcD = 0;
            USrcD = 0;

        end

        7'b1100011 : begin //BranchD 
            RegWriteD = 1'b0;
            ImmSrcD = 3'b010;
            ALUSrcD = 0;
            MemWriteD = 0;
            BranchD = 1;
            ALUOp = 2'b01;
            JumpD = 0;
            JalSrcD = 0;
            USrcD = 0;
            //zero_flag = 1;

        end

        7'b1101111 : begin // JumpD 
            RegWriteD = 1'b1;
            ImmSrcD = 3'b011;
            MemWriteD = 0;
            ResultSrcD = 2'b10;
            BranchD = 0;
            JumpD = 1;
            JalSrcD = 0;
            USrcD = 0;
            //zero_flag = 1;

        end

        7'b1100111 : begin // jalr
            RegWriteD = 1'b1;
            ImmSrcD = 3'b000;
            MemWriteD = 0;
            ResultSrcD = 2'b10;
            BranchD = 0;
            JumpD = 1;
            JalSrcD = 1;
            USrcD = 0;
            //zero_flag = 1;

        end

        7'b0110111 : begin // lui 
            RegWriteD = 1'b1;
            ImmSrcD = 3'b100;
            MemWriteD = 0;
            ResultSrcD = 2'b11;
            BranchD = 0;
            JumpD = 0;
            UOControlD = 1;
            // JalSrcD = 0;
            // USrcD = 0;
            //zero_flag = 1;

        end

        7'b0010111 : begin // aupic 
            RegWriteD = 1'b1;
            ImmSrcD = 3'b100;
            MemWriteD = 0;
            ResultSrcD = 2'b11;
            BranchD = 0;
            JumpD = 0;
            JalSrcD = 0;
            USrcD = 1;
            UOControlD = 0;
            //zero_flag = 1;

        end

        default : begin
            // Default values to handle invalid opcodes
            RegWriteD = 1'b0;
            ImmSrcD = 3'b000;
            ALUSrcD = 0;
            MemWriteD = 0;
            ResultSrcD = 2'b00;
            BranchD = 0;
            ALUOp = 2'b00;
            JumpD = 0;
            JalSrcD = 0;
            USrcD = 0;
            UOControlD = 0;
        end
    endcase

end

endmodule
