/////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: output_port_lookup.v 5240 2009-03-14 01:50:42Z grg $
//
// Module: output_port_lookup.v
// Project: 4-port NIC
// Description: Connects the MAC ports to the CPU DMA ports
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

  module output_port_lookup
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2,
      parameter INPUT_ARBITER_STAGE_NUM = 2,
      parameter IO_QUEUE_STAGE_NUM = `IO_QUEUE_STAGE_NUM,
      parameter NUM_OUTPUT_QUEUES = 8,
      parameter NUM_IQ_BITS = 3,
      parameter STAGE_NUM = 4,
      parameter CPU_QUEUE_NUM = 0)

   (// --- data path interface
    output reg  [DATA_WIDTH-1:0]           out_data,
    output reg [CTRL_WIDTH-1:0]           out_ctrl,
    output reg                            out_wr,
    input                                 out_rdy,

    input  [DATA_WIDTH-1:0]               in_data,
    input  [CTRL_WIDTH-1:0]               in_ctrl,
    input                                 in_wr,
    output                                in_rdy,

    // --- Register interface
    input                                 reg_req_in,
    input                                 reg_ack_in,
    input                                 reg_rd_wr_L_in,
    input  [`UDP_REG_ADDR_WIDTH-1:0]      reg_addr_in,
    input  [`CPCI_NF2_DATA_WIDTH-1:0]     reg_data_in,
    input  [UDP_REG_SRC_WIDTH-1:0]        reg_src_in,

    output reg                            reg_req_out,
    output reg                            reg_ack_out,
    output reg                            reg_rd_wr_L_out,
    output reg [`UDP_REG_ADDR_WIDTH-1:0]  reg_addr_out,
    output reg [`CPCI_NF2_DATA_WIDTH-1:0] reg_data_out,
    output reg [UDP_REG_SRC_WIDTH-1:0]    reg_src_out,

    // --- Misc
    input                                 clk,
    input                                 reset);

   function integer log2;
      input integer number;
      begin
	 log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end

      end

   endfunction

   //--------------------- Internal Parameter-------------------------
   localparam IN_MODULE_HDRS	  = 4'd0;
   localparam DST_ADDR		  = 4'd1;
   localparam SRC_ADDR            = 4'd2;
   localparam CHECK_SRC_CAM	  = 4'd3;
   localparam CHECK_DST_CAM	  = 4'd4;
   localparam CHECK_RAM		  = 4'd5;
   localparam STORE_CAM		  = 4'd6;
   localparam STORE_RAM		  = 4'd7;
   localparam IN_PACKET		  = 4'd8;


   //---------------------- Wires/Regs -------------------------------
   reg [DATA_WIDTH-1:0] in_data_modded;

   reg [15:0] 		decoded_src, src_addr_1;
   reg [15:0]       port_srcaddr, port_dstaddr;
   reg [15:0]       hits, misses;
   wire [DATA_WIDTH-1:0] out_data_modded;
   wire [CTRL_WIDTH-1:0] out_ctrl_modded;
   reg [3:0]            state, state_nxt;
   reg                  read_cam_dst, read_cam_dst2, read_cam_src;
   reg [47:0]		src_addr;
   reg [47:0]		dst_addr;
   reg [63:0]		pack1;
   reg [3:0]            count_cam = 4'b0;
   reg [3:0]		count = 0;
   reg [15:0]		src_port;
   reg [47:0]		cam_in, cam_cmp;
   reg 			cam_we, cam_en, ram_we;
   reg                  send_pkt, new_pkt;
   reg [3:0]		cam_addr, ram_addr, cam_index, dst_cam_index;
   reg                  ram_index = 1'b0;
   reg [55:0]		ram_in;
   wire                 cam_match;
   wire [55:0] 	        ram_out;
   wire                 cam_busy;
   wire [3:0] 		cam_out;

   //----------------------- Modules ---------------------------------
   small_fifo #(.WIDTH(CTRL_WIDTH+DATA_WIDTH), .MAX_DEPTH_BITS(2))
      input_fifo
        (.din           ({in_ctrl, in_data_modded}),  // Data in
         .wr_en         (in_wr),             // Write enable
         .rd_en         (in_fifo_rd_en),    // Read the next word
         .dout          ({out_ctrl_modded, out_data_modded}),
         .full          (),
         .prog_full     (),
         .nearly_full   (in_fifo_nearly_full),
         .empty         (in_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );
   //-----------------------CAM for MAC Address---------------------
    cam_mac mac(
	.clk		(clk),
	.cmp_din	(cam_cmp),	//Bus [47:0]
	.din		(cam_in), 	//Bus [47:0]
	.en		(cam_en),
	.we		(cam_we),
	.wr_addr	(cam_addr),	//Bus [3:0]
	.busy		(cam_busy),
	.match		(cam_match),
	.match_addr	(cam_out));	//Bus [3:0]
   //-----------------------RAM for PORT Address--------------------
	ram_mem port (
	.clka		(clk),
	.dina		(ram_in),	// Bus [55:0]
	.addra		(ram_addr),	// Bus [3:0]
	.wea		(ram_we),	// Bus[0:0]
	.douta		(ram_out));	// Bus[55:0]
   //----------------------- Logic ---------------------------------

   assign in_rdy = !in_fifo_nearly_full;

   /* pkt is from the cpu if it comes in on an odd numbered port */
   assign pkt_is_from_cpu = in_data[`IOQ_SRC_PORT_POS];

   /* modify the IOQ module header */
   always @(*) begin

	in_data_modded   = in_data;
//	state_nxt        = state;  can't change states twice, and not on a clock
	decoded_src	 = 0;
	decoded_src[in_data[`IOQ_SRC_PORT_POS+15:`IOQ_SRC_PORT_POS]] = 1'b1;

    case (state)
		IN_MODULE_HDRS: begin

        	if(in_wr && in_ctrl==IO_QUEUE_STAGE_NUM) begin
            	read_cam_dst = 1'b0;
	       		send_pkt = 0;
               	if(pkt_is_from_cpu) begin
			  		port_srcaddr = 16'b0;
				  	in_data_modded[`IOQ_DST_PORT_POS+15:`IOQ_DST_PORT_POS] = port_srcaddr;
		       	end

				else
              	 	port_srcaddr = decoded_src;
        		state_nxt = DST_ADDR;
	    	end // if (in_wr && in_ctrl==IO_QUEUE_STAGE_NUM)
        end // case: IN_MODULE_HDRS

        DST_ADDR:  begin

			if(in_wr && in_ctrl == 0 ) begin
	    		pack1 = in_data;
		  		dst_addr = pack1[63:16];
		  		src_addr_1 = pack1[15:0];
            	read_cam_dst = 1;
		  		state_nxt = SRC_ADDR;
	    	end
	 	end // case: DST_ADDR

        SRC_ADDR: begin

	   		src_addr = {src_addr_1, in_data[63:32]};
			//cam_in = src_addr;
		  	cam_en = 1;
		  	state_nxt = CHECK_SRC_CAM;
	  	end // case: SRC_ADDR

		CHECK_SRC_CAM: begin

			cam_cmp = src_addr;
			if(!cam_busy) begin
				if(cam_match) begin
					cam_index = cam_out;
	//				cam_en = 0;
					ram_we = 1;
					state_nxt = STORE_RAM;
				end
				else begin
					cam_we = 1;
					state_nxt = STORE_CAM;
				end
			end
		end // case: CHECK_SRC_CAM

		CHECK_DST_CAM: begin

			cam_cmp = dst_addr;
			if(!cam_busy) begin
				if(cam_match) begin
					ram_index = cam_out;
					cam_en = 0;
					state_nxt = CHECK_RAM;
				end
				else begin
					port_dstaddr = ~port_srcaddr & 16'h0055;
					send_pkt = 1;
					state_nxt = IN_PACKET;
				end
			end
		end // case: CHECK_DST_CAM

		CHECK_RAM: begin
         	ram_index = ram_addr;
			if(ram_index == ram_addr) begin
				port_dstaddr = ram_out[55:48];
				send_pkt = 1;
			end
			state_nxt = IN_PACKET;
		end

		STORE_CAM: begin
			cam_addr = count;
			cam_in = src_addr;
         		cam_we = 0;
				ram_we = 1;
			state_nxt = STORE_RAM;
		end // case: STORE_CAM

		STORE_RAM: begin
			ram_addr = count;
			ram_in[55:0] = {port_srcaddr,src_addr};
			count = count+1;
			state_nxt = CHECK_DST_CAM;
		end

       	IN_PACKET:  begin

			if(in_wr && in_ctrl!=0)begin
			  	state_nxt = IN_MODULE_HDRS;
			end
		end

    endcase // case (state)
	end // always @ (*)
	   always @(posedge clk) begin
		if(reset) begin
			state <= IN_MODULE_HDRS;
			ram_we <= 0;
			cam_we <= 0;
			cam_en <= 0;
			hits   <= 0;
			misses <= 0;
		end
		else begin
			state <= state_nxt;
		end
	end

	/* handle outputs */
	assign in_fifo_rd_en = (out_rdy && send_pkt && !in_fifo_empty);
	always @(posedge clk) begin
		out_wr <= reset ? 0 : in_fifo_rd_en;
		if(out_ctrl_modded != IO_QUEUE_STAGE_NUM) begin
			out_data <= out_data_modded;
		  	out_ctrl <= out_ctrl_modded;
	  	end
	  	else begin
		  	out_ctrl <= out_ctrl_modded;
		  	out_data <= {port_dstaddr, out_data_modded[47:0]};
	  	end
	end // always @ (posedge clk)


   /* registers unused */
   always @(posedge clk) begin

      reg_req_out        <= reg_req_in;
      reg_ack_out        <= reg_ack_in;
      reg_rd_wr_L_out    <= reg_rd_wr_L_in;
      reg_addr_out       <= reg_addr_in;
      reg_data_out       <= reg_data_in;
      reg_src_out        <= reg_src_in;
   end

endmodule // output_port_lookup

