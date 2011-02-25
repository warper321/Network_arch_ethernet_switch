<<<<<<< HEAD
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
   localparam IN_ETHERNET_HDRS    = 4'd1;
   localparam IN_PACKET           = 4'd2;
   
   //---------------------- Wires/Regs -------------------------------
   reg [DATA_WIDTH-1:0] in_data_modded;
   
   reg [15:0] 		decoded_src;
   wire [DATA_WIDTH-1:0] out_data_modded;
   wire [CTRL_WIDTH-1:0] out_ctrl_modded;
 
   reg [15:0]       decoded_dst;
   reg              state, state_nxt;
   reg [47:0]		source_addr;
   reg [47:0]		dst_addr;
   reg [63:0]		pack1;
   reg [63:0]		pack2;
   reg [1:0]		count;
   reg [15:0]		src_port;
   reg [47:0]		cam_in;
   reg 			cam_we, ram_we, send_pkt;
   reg [3:0]		cam_addr, ram_addr, cam_index, ram_index;
   reg [15:0]		ram_in, ram_port;
   wire                 cam_match;
   wire [15:0] 	        ram_out;
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
	cam_mac mac (clk, cam_in, cam_we, cam_addr, cam_busy, cam_match, cam_out);
	//-----------------------RAM for PORT Address--------------------
	ram_port port (clk, ram_in, ram_addr, ram_we, ram_out);
   //----------------------- Logic ---------------------------------

   assign in_rdy = !in_fifo_nearly_full;

   /* pkt is from the cpu if it comes in on an odd numbered port */
   assign pkt_is_from_cpu = in_data[`IOQ_SRC_PORT_POS];

  
   /* modify the IOQ module header */
   always @(*) begin

    in_data_modded   = in_data;
    state_nxt        = state;
	decoded_src = 0;
	decoded_src[in_data[`IOQ_SRC_PORT_POS+15:`IOQ_SRC_PORT_POS]] = 1'b1;
	src_port = in_data[`IOQ_SRC_PORT_POS+15:`IOQ_SRC_PORT_POS];
      
      case (state)
         IN_MODULE_HDRS: begin
			count = 2'b00;
	    
            if(in_wr && in_ctrl==IO_QUEUE_STAGE_NUM) begin
	       
               if(pkt_is_from_cpu) begin
		ram_port = ~decoded_src & 16'b0000000001010101;
                in_data_modded[`IOQ_DST_PORT_POS+15:`IOQ_DST_PORT_POS] = ram_port;
               end
	       
            end
	    
            if(in_wr && in_ctrl==0) begin
               state_nxt = IN_ETHERNET_HDRS;
            end
	    
         end // case: IN_MODULE_HDRS
         
         IN_ETHERNET_HDRS: begin
	    	    
            if(in_wr) begin
	       if(count == 2'b00) begin
			count = 2'b01;
	       end
	       	       
	       else if(count == 2'b01) begin
		    pack1 = in_data;
		  dst_addr = pack1[63:16];
		  count = 2'b10;
	       end
	       
	              	       
	      else if(count == 2'b10) begin
		    pack2 = in_data;
		  source_addr = {pack1[15:0], pack2[63:32]};
		   count = 2'b00;
		    state_nxt = IN_PACKET;
	      end
	       
	       cam_in = source_addr;
	       
			if(cam_match) begin
			   	cam_index = cam_out;
				ram_index = cam_index;
				ram_index = ram_addr;
				send_pkt = 1;
				ram_port = ram_out;
			end
	              
			else begin
				cam_in = source_addr;
				ram_addr = cam_out;
				ram_in = ram_port; 
				send_pkt = 1;
			end // else: !if(cam_match)
	       
	    end // if (in_wr)
	 end // case: IN_ETHERNET_HDRS
	      
          		 
                 IN_PACKET: begin
		    if(in_wr && in_ctrl!=0)begin
		       
		      state_nxt = IN_MODULE_HDRS;
		    end
		    
		 end
      
        endcase // case(state)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         state <= IN_MODULE_HDRS;
      end
      
      else begin
         state <= state_nxt;
      end
   end

   /* handle outputs */
   assign in_fifo_rd_en = out_rdy && !in_fifo_empty && send_pkt;
   always @(posedge clk) begin
    out_wr <= reset ? 0 : in_fifo_rd_en;
	if(out_ctrl_modded != IO_QUEUE_STAGE_NUM) begin
		out_data <= out_data_modded;
		out_ctrl <= out_ctrl_modded;
	end
      
		else begin
		out_ctrl <= out_ctrl_modded;
		out_data <= {ram_port, out_data_modded[47:0]};
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

=======
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
    output     [DATA_WIDTH-1:0]           out_data,
    output     [CTRL_WIDTH-1:0]           out_ctrl,
    output reg                            out_wr,
    input                                 out_rdy,

    input  [DATA_WIDTH-1:0]               in_data,
    input  [DATA_WIDTH-1:0]		  switch_data,		
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
   endfunction // log2

   //--------------------- Internal Parameter-------------------------
   localparam IN_MODULE_HDRS   = 0;
   localparam IN_PACKET        = 1;

   //---------------------- Wires/Regs -------------------------------
   reg [DATA_WIDTH-1:0] in_data_modded;
   reg [15:0]           decoded_src;
   reg [15:0] 		decoded_dst;
   reg                  state, state_nxt;
   reg [47:0]		mac;
   reg 			cam_we, port_we;
   reg [3:0]		cam_addr, port_addr;
   wire			cam_busy, cam_match, port_busy, port_match;
   reg [1:0]         count;
   reg [63:0]		pack1, pack2;
   wire [3:0]		cam_match_addr,port_match_addr;
   reg [15:0] 		port;
   
   //----------------------- Modules ---------------------------------
   small_fifo #(.WIDTH(CTRL_WIDTH+DATA_WIDTH), .MAX_DEPTH_BITS(2))
      input_fifo
        (.din           ({in_ctrl, in_data_modded}),  // Data in
         .wr_en         (in_wr),             // Write enable
         .rd_en         (in_fifo_rd_en),    // Read the next word
         .dout          ({out_ctrl, out_data}),
         .full          (),
         .prog_full     (),
         .nearly_full   (in_fifo_nearly_full),
         .empty         (in_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

 //--------------------------CAM--------------------------------
   cam_v6_1 cam(clk, mac, cam_we, cam_addr, cam_busy, cam_match, cam_match_addr);

   //-----------------------CAM for Port Num---------------------------------
   cam_v6_1 mem(clk, port,port_we, port_addr, port_busy, port_match, port_match_addr);
   
   
  //--------------- Logic ---------------------------------

   assign in_rdy = !in_fifo_nearly_full;

   /* pkt is from the cpu if it comes in on an odd numbered port */
   assign pkt_is_from_cpu = in_data[`IOQ_SRC_PORT_POS];

   /* Decode the source port */
   always @(*) begin
      decoded_src = 0;
      decoded_src[in_data[`IOQ_SRC_PORT_POS+15:`IOQ_SRC_PORT_POS]] = 1'b1;
      port_we = 0;
      port = in_data[`IOQ_SRC_PORT_POS+15:`IOQ_SRC_PORT_POS];
      if(!(port_match)) begin
	port_addr = port;
        switch_data[`SWITCH_OP_LUT_PORTS_MAC_HI_REG+31] = 1;
      end
	else
	switch_data[`SWITCH_OP_LUT_PORTS_MAC_HI_REG+31] = 0;
	
            
   end

/*modify the IOQ module header */
   always @(*) begin

      in_data_modded   = in_data;
      state_nxt        = state;

      case(state)
	
         IN_MODULE_HDRS: begin
		  count = 2b'00';
            if(in_wr && in_ctrl==IO_QUEUE_STAGE_NUM) begin
               if(pkt_is_from_cpu) begin
                  in_data_modded[`IOQ_DST_PORT_POS+15:`IOQ_DST_PORT_POS] = ~decoded_src & 16'b0000000001010101;
               end
                           end
            if(in_wr && in_ctrl==0) begin
               state_nxt = IN_ETHERNET_HDRS;
            end
         end // case: IN_MODULE_HDRS
         
         IN_ETHERNET_HDRS: begin
            if(in_wr) begin
			if(count == 2b'00')
				count = 2b'01';
			else if(count == 2b'01')
				begin
					pack1 = in_data;
					//register for source address = pack1[63:16]
				count = 2b'10';
				end
			else if(count == 2b'10')
				begin
					pack2 = in_data;
					//register for dest address = {pack1[15:0], pack2[63:32]}
					count = 2b'00';
					state_nxt = IN_PACKET;
				end
				
         IN_PACKET: begin
            if(in_wr && in_ctrl!=0) begin
               state_nxt = IN_MODULE_HDRS;
	    end
	    
	else begin
	       decoded_sa_mac = in_data[`
         end
      endcase // case(state)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         state <= IN_MODULE_HDRS;
      end
      else begin
         state <= state_nxt;
      end
   end

   /* handle outputs */
   assign in_fifo_rd_en = out_rdy && !in_fifo_empty && decoded_dst;
   always @(posedge clk) begin
      out_wr <= reset ? 0 : in_fifo_rd_en;
   end

   /* registers unused */
   always @(posedge clk) begin
      reg_req_out        <= reg_req_in;
      reg_ack_out        <= reg_ack_in;
      reg_rd_wr_L_out    <= reg_rd_wr_L_in;
      reg_addr_out       <= reg_addr_in;
      reg_data_out       <= reg_data_in;
      reg_src_out        <= reg_src_in;
   end

endmodule
>>>>>>> de7914fd4b82e26074e028150af4fe2ef8bbe773
