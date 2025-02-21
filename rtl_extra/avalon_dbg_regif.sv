//
// Copyright (C) 2025  Markus Hiienkari <mhiienka@niksula.hut.fi>
//
// This file is part of Open Source Scan Converter project.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

module avalon_dbg_regif(
    // common
    input clk_i,
    input rst_i,
    // avalon slave
    input [31:0] avalon_s_writedata,
    output reg [31:0] avalon_s_readdata,
    input [9:0] avalon_s_address,
    input [3:0] avalon_s_byteenable,
    input avalon_s_write,
    input avalon_s_read,
    input avalon_s_chipselect,
    output reg [1:0] avalon_s_response,
    output reg avalon_s_readdatavalid,
    output reg avalon_s_writeresponsevalid,
    output avalon_s_waitrequest_n,
    // DMI interface
    input dmi_req_ready_i,
    output dm::dmi_req_t dmi_req_o,
    output dmi_req_valid_o,
    input dm::dmi_resp_t dmi_resp_i,
    input dmi_resp_valid_i,
    output dmi_resp_ready_o,
    // Misc
    output debug_req,
    output sleep_req,
    output dmi_rst_req
);

// Latter half of address space reserved for custom/glue regs
localparam CTRL_REGADDR =       10'h200;

reg [31:0] config_reg;
reg wip, rip;

assign avalon_s_waitrequest_n = dmi_req_ready_i & ~wip & ~rip;
assign dmi_resp_ready_o = 1'b1;

always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        config_reg <= '0;
        avalon_s_writeresponsevalid <= 1'b0;
        avalon_s_readdatavalid <= 1'b0;
        dmi_req_valid_o <= 1'b0;
        wip <= 0;
        rip <= 0;
    end else begin
        avalon_s_writeresponsevalid <= 1'b0;
        avalon_s_readdatavalid <= 1'b0;
        dmi_req_valid_o <= 1'b0;

        if (wip) begin
            if (dmi_resp_valid_i) begin
                avalon_s_response <= (dmi_resp_i.resp == 0) ? 2'h0 : 2'h2;
                avalon_s_writeresponsevalid <= 1;
                wip <= 0;
            end
        end else if (rip) begin
            if (dmi_resp_valid_i) begin
                avalon_s_response <= (dmi_resp_i.resp == 0) ? 2'h0 : 2'h2;
                avalon_s_readdata <= dmi_resp_i.data;
                avalon_s_readdatavalid <= 1;
                rip <= 0;
            end
        end else if (avalon_s_chipselect && avalon_s_write) begin
            if (avalon_s_address == CTRL_REGADDR) begin
                if (avalon_s_byteenable[3])
                    config_reg[31:24] <= avalon_s_writedata[31:24];
                if (avalon_s_byteenable[2])
                    config_reg[23:16] <= avalon_s_writedata[23:16];
                if (avalon_s_byteenable[1])
                    config_reg[15:8] <= avalon_s_writedata[15:8];
                if (avalon_s_byteenable[0])
                    config_reg[7:0] <= avalon_s_writedata[7:0];
                avalon_s_response <= 2'h0;
                avalon_s_writeresponsevalid <= 1;
            end else if (avalon_s_address < CTRL_REGADDR) begin
                dmi_req_o.addr <= avalon_s_address[8:2];
                dmi_req_o.op <= dm::DTM_WRITE;
                dmi_req_o.data <= avalon_s_writedata; // assume byte-enabled is not used
                dmi_req_valid_o <= 1'b1;
                wip <= 1;
            end else begin
                avalon_s_response <= 2'h2;
                avalon_s_writeresponsevalid <= 1;
            end
        end else if (avalon_s_chipselect && avalon_s_read) begin
            if (avalon_s_address == CTRL_REGADDR) begin
                avalon_s_response <= 2'h0;
                avalon_s_readdata <= config_reg;
                avalon_s_readdatavalid <= 1'b1;
            end else if (avalon_s_address < CTRL_REGADDR) begin
                dmi_req_o.addr <= avalon_s_address[8:2];
                dmi_req_o.op <= dm::DTM_READ;
                dmi_req_valid_o <= 1'b1;
                rip <= 1;
            end else begin
                avalon_s_readdata <= 32'h00000000;
                avalon_s_readdatavalid <= 1'b1;
                avalon_s_response <= 2'h2;
            end
        end
    end
end

assign debug_req = config_reg[0];
assign sleep_req = config_reg[1];
assign dmi_rst_req = config_reg[2];

endmodule
