`default_nettype none 

module ALU (
    input [31:0] SrcAE,
    input [31:0] SrcBE,
    input [3:0] ALUControlE,
    output reg [31:0] ALUResultE,
    output reg ZeroE
);

    always @(*) begin
        ZeroE = 0;
        ALUResultE = 0;

            case (ALUControlE) 
                4'b0000 : ALUResultE = SrcAE + SrcBE; // addition
                4'b0001 : ALUResultE = SrcAE - SrcBE; //sub
                4'b0101 : ALUResultE = (SrcAE < SrcBE) ? 32'b1 : 32'b0; //slt
                4'b0100 : ALUResultE = ($unsigned(SrcAE) < $unsigned(SrcBE)) ? 32'b1 : 32'b0; //R OR I TYPE sltu
                4'b0110 : ALUResultE = SrcAE ^ SrcBE; //R OR I TYPE xor
                4'b0011 : ALUResultE = SrcAE | SrcBE; //R OR I TYPE or
                4'b0010 : ALUResultE = SrcAE & SrcBE; //R OR I TYPE and
                4'b0111 : ALUResultE = SrcAE << SrcBE[4:0]; //R OR I TYPE sll
                4'b1000 : ALUResultE = SrcAE >> SrcBE[4:0]; //R OR I TYPE srl
                4'b1001 : ALUResultE = $signed(SrcAE) >>> SrcBE[4:0]; //R OR I TYPE sra

                4'b1010 : ZeroE = (SrcAE == SrcBE) ? 1 : 0; // BEQ
                4'b1011 : ZeroE = (SrcAE != SrcBE) ? 1 : 0; // BNE
                4'b1100 : ZeroE = ($signed(SrcAE) < $signed(SrcBE)) ? 1 : 0; // BLT
                4'b1101 : ZeroE = ($signed(SrcAE) >= $signed(SrcBE)) ? 1 : 0; // BGE
                4'b1110 : ZeroE = ($unsigned(SrcAE) < $unsigned(SrcBE)) ? 1 : 0; // BLTU
                4'b1111 : ZeroE = ($unsigned(SrcAE) >= $unsigned(SrcBE)) ? 1 : 0; // BGEU
                default : begin
                    ALUResultE = 32'b0;
                    ZeroE = 0;
                end
            endcase
    end

endmodule
