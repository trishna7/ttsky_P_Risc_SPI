`default_nettype none

module ALU_Decoder(
    input opcode_bit5,
    input [2:0] funct3,
    input funct7_bit5,
    input [1:0] ALUOp,
    output reg [3:0] ALUControlD
);

always @(*) begin
    case (ALUOp)
        2'b00 : ALUControlD = 4'b0000; //addition load, store
        2'b01 : begin
            //ALUControlD = 4'b0001; // sub branch check 
                case (funct3)
                    3'b000: ALUControlD = 4'b1010; // BEQ
                    3'b001: ALUControlD = 4'b1011; // BNE
                    3'b100: ALUControlD = 4'b1100; // BLT
                    3'b101: ALUControlD = 4'b1101; // BGE
                    3'b110: ALUControlD = 4'b1110; // BLTU
                    3'b111: ALUControlD = 4'b1111; // BGEU                    
                endcase
        end

        2'b10: begin
            // Using nested if-else instead of multi-bit case
            if (funct3 == 3'b000 && opcode_bit5 == 1'b1 && funct7_bit5 == 1'b0)
                ALUControlD = 4'b0000; // R or I type addition
            else if (funct3 == 3'b000 && opcode_bit5 == 1'b1 && funct7_bit5 == 1'b1)
                ALUControlD = 4'b0001; // R or I type subtraction
            else if (funct3 == 3'b010 && opcode_bit5 == 1'b1 && funct7_bit5 == 1'b0)
                ALUControlD = 4'b0101; // R or I type slt
            else if (funct3 == 3'b011 && opcode_bit5 == 1'b1 && funct7_bit5 == 1'b0)
                ALUControlD = 4'b0100; // R or I type sltu
            else if (funct3 == 3'b100 && opcode_bit5 == 1'b1 && funct7_bit5 == 1'b0)
                ALUControlD = 4'b0110; // R or I type xor
            else if (funct3 == 3'b110 && opcode_bit5 == 1'b1 && funct7_bit5 == 1'b0)
                ALUControlD = 4'b0011; // R or I type or
            else if (funct3 == 3'b111 && opcode_bit5 == 1'b1 && funct7_bit5 == 1'b0)
                ALUControlD = 4'b0010; // R or I type and
            else if (funct3 == 3'b001 && opcode_bit5 == 1'b1 && funct7_bit5 == 1'b0)
                ALUControlD = 4'b0111; // R or I type sll
            else if (funct3 == 3'b101 && opcode_bit5 == 1'b1 && funct7_bit5 == 1'b0)
                ALUControlD = 4'b1000; // R or I type srl
            else if (funct3 == 3'b101 && opcode_bit5 == 1'b1 && funct7_bit5 == 1'b1)
                ALUControlD = 4'b1001; // R or I type sra
            else
                ALUControlD = 4'b0000; // Default
        end
        default: ALUControlD = 4'b0000;
    endcase
end
endmodule
