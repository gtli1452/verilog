/* Filename : diff_freq_serial_out.v
 * Simulator: ModelSim - Intel FPGA Edition vsim 2020.1
 * Complier : Quartus Prime - Standard Edition 20.1.1
 *
 * Serially output 32-bit data by different frequency
 */

`include "user_cmd.vh"

module diff_freq_serial_out #(
  parameter       DATA_BIT    = 32,
  parameter       OUTPUT_NUM  = 16,
  parameter [7:0] SLOW_PERIOD = 20,
  parameter [7:0] FAST_PERIOD = 5
) (
  input                   clk_i,
  input                   rst_ni,
  input  [7:0]            data_i,
  input                   rx_done_tick_i,
  output [OUTPUT_NUM-1:0] serial_out_o
);

  /* State declaration */
  localparam [2:0] S_IDLE   = 3'b000;
  localparam [2:0] S_DATA   = 3'b001;
  localparam [2:0] S_CTRL   = 3'b010;
  localparam [2:0] S_REPEAT = 3'b011;
  localparam [2:0] S_RUN    = 3'b100;
  localparam [2:0] S_DONE   = 3'b101;

  /* Signal declaration */
  // to load the decoder output
  reg [2:0]          state_reg,   state_next;
  reg [8:0]          amount_reg,  amount_next;
  reg [7:0]          addr_reg, addr_next;
  reg [7:0]          output_reg,  output_next;
  reg [DATA_BIT-1:0] freq_reg,    freq_next;
  reg [7:0]          sel_out_reg, sel_out_next;
  reg                enable_reg,  enable_next;
  reg                run_reg,    run_next;
  reg                idle_reg,    idle_next;
  reg [1:0]          mode_reg,    mode_next;
  reg [7:0]          slow_period_reg, slow_period_next;
  reg [7:0]          fast_period_reg, fast_period_next;
  reg [7:0]          repeat_reg, repeat_next;
  reg                update_tick;

  // Decoder signal
  wire [8:0]          decode_amount;
  wire [7:0]          decode_addr;
  wire [7:0]          decode_output;
  wire [DATA_BIT-1:0] decode_freq;
  wire [7:0]          decode_sel_out;
  wire                decode_enable;
  wire                decode_run;
  wire                decode_idle;
  wire [1:0]          decode_mode;
  wire [7:0]          decode_slow_period;
  wire [7:0]          decode_fast_period;
  wire [7:0]          decode_repeat;
  wire [7:0]          decode_cmd;
  wire                decode_done_tick;

  // Signal to serial out entity
  reg [8:0]            channel_amount[OUTPUT_NUM-1:0];
  reg [8:0]            channel_amount_next[OUTPUT_NUM-1:0];
  reg [OUTPUT_NUM-1:0] channel_enable, channel_enable_next;
  reg [OUTPUT_NUM-1:0] channel_idle,  channel_idle_next;
  reg [1:0]            channel_mode[OUTPUT_NUM-1:0];
  reg [1:0]            channel_mode_next[OUTPUT_NUM-1:0];
  reg [7:0]            channel_repeat[OUTPUT_NUM-1:0];
  reg [7:0]            channel_repeat_next[OUTPUT_NUM-1:0];
  reg [OUTPUT_NUM-1:0] channel_update_data;
  wire [11:0]          channel_bit_count[OUTPUT_NUM-1:0];
  wire [7:0]           channel_period[OUTPUT_NUM-1:0];

  // Wire assignment
  // Create start_tick for one-shot
  wire [OUTPUT_NUM-1:0] start_tick;
  assign start_tick = channel_enable & {OUTPUT_NUM{update_tick}};

  // Stop signal for serial_out module
  wire stop = ~run_reg;

  // for loop variable
  integer i;

  /* Body */
  /* FSMD state & data registers */
  always @(posedge clk_i,  negedge rst_ni) begin
    if (~rst_ni)
      begin
        state_reg       <= S_IDLE;
        amount_reg      <= 0;
        addr_reg        <= 0;
        output_reg      <= 0;
        sel_out_reg     <= 0;
        enable_reg      <= 0;
        run_reg         <= 0;
        idle_reg        <= 0;
        mode_reg        <= 0;
        freq_reg        <= 0;
        slow_period_reg <= SLOW_PERIOD; // 5MHz
        fast_period_reg <= FAST_PERIOD; // 20MHz
        repeat_reg      <= 0;
        // control bit pattern
        channel_enable  <= 0;
        channel_idle    <= 0;

        for (i = 0; i < OUTPUT_NUM; i = i + 1)
          begin
            channel_mode[i] <= 0;
            channel_repeat[i] <= 0;
            channel_amount[i] <= 0;
          end
      end
    else
      begin
        state_reg       <= state_next;
        amount_reg      <= amount_next;
        addr_reg        <= addr_next;
        output_reg      <= output_next;
        sel_out_reg     <= sel_out_next;
        enable_reg      <= enable_next;
        run_reg         <= run_next;
        idle_reg        <= idle_next;
        mode_reg        <= mode_next;
        freq_reg        <= freq_next;
        slow_period_reg <= slow_period_next;
        fast_period_reg <= fast_period_next;
        repeat_reg      <= repeat_next;
        // control bit pattern
        channel_enable  <= channel_enable_next;
        channel_idle    <= channel_idle_next;

        for (i = 0; i < OUTPUT_NUM; i = i + 1'b1)
          begin
            channel_mode[i] <= channel_mode_next[i];
            channel_repeat[i] <= channel_repeat_next[i];
            channel_amount[i] <= channel_amount_next[i];
          end
      end
  end

  /* FSMD next-state logic & functional units */
  // update the output pattern
  always @(*) begin
    state_next       = state_reg;
    amount_next      = amount_reg;
    addr_next        = addr_reg;
    output_next      = output_reg;
    sel_out_next     = sel_out_reg;
    enable_next      = enable_reg;
    run_next         = run_reg;
    idle_next        = idle_reg;
    mode_next        = mode_reg;
    freq_next        = freq_reg;
    slow_period_next = slow_period_reg;
    fast_period_next = fast_period_reg;
    repeat_next      = repeat_reg;
    // control bit pattern
    channel_enable_next = channel_enable;
    channel_idle_next = channel_idle;
    channel_update_data = 0;
    update_tick = 0;

    for (i = 0; i < OUTPUT_NUM; i = i + 1'b1)
      begin
        channel_mode_next[i] = channel_mode[i];
        channel_repeat_next[i] = channel_repeat[i];
        channel_amount_next[i] = channel_amount[i];
      end

    case (state_reg)
      S_IDLE: begin
        if (decode_done_tick)
          begin
            if (decode_cmd == `CMD_DATA)
              begin
                sel_out_next = decode_sel_out;
                amount_next = decode_amount;
                addr_next = decode_addr;
                output_next = decode_output;
                state_next = S_DATA;
              end
            else if (decode_cmd == `CMD_FREQ)
              begin
                freq_next = decode_freq;
              end
            else if (decode_cmd == `CMD_PERIOD)
              begin
                slow_period_next = decode_slow_period;
                fast_period_next = decode_fast_period;
              end
            else if (decode_cmd == `CMD_CTRL)
              begin
                sel_out_next = decode_sel_out;
                enable_next = decode_enable;
                mode_next = decode_mode;
                idle_next = decode_idle;
                state_next = S_CTRL;
              end
            else if (decode_cmd == `CMD_REPEAT)
              begin
                sel_out_next = decode_sel_out;
                repeat_next = decode_repeat;
                state_next = S_REPEAT;
              end
            else if (decode_cmd == `CMD_GLOBAL)
              begin
                run_next = decode_run;
                state_next = S_RUN;
              end
          end
      end

      S_DATA: begin
        state_next = S_IDLE;
        channel_update_data[sel_out_reg] = 1'b1;
        channel_amount_next[sel_out_reg] = amount_reg;
      end

      S_CTRL: begin
        state_next = S_IDLE;
        channel_enable_next[sel_out_reg] = enable_reg;
        channel_idle_next[sel_out_reg] = idle_reg;
        channel_mode_next[sel_out_reg] = mode_reg;
      end

      S_REPEAT: begin
        state_next = S_IDLE;
        channel_repeat_next[sel_out_reg] = repeat_reg;
      end

      S_RUN: begin
        state_next = S_DONE;
      end

      S_DONE: begin
        state_next  = S_IDLE;
        update_tick = 1;
      end

      default: state_next = S_IDLE;
    endcase
  end

  decoder #(
    .DATA_BIT        (DATA_BIT)
  ) decoder_dut (
    .clk_i           (clk_i),
    .rst_ni          (rst_ni),
    .data_i          (data_i),
    .rx_done_tick_i  (rx_done_tick_i),
    .amount_o        (decode_amount),
    .output_pattern_o(decode_output),
    .freq_pattern_o  (decode_freq),
    .sel_out_o       (decode_sel_out),
    .enable_o        (decode_enable),
    .run_o           (decode_run),
    .idle_o          (decode_idle),
    .mode_o          (decode_mode),
    .slow_period_o   (decode_slow_period),
    .fast_period_o   (decode_fast_period),
    .repeat_o        (decode_repeat),
    .cmd_o           (decode_cmd),
    .addr_o          (decode_addr),
    .done_tick_o     (decode_done_tick)
  );

  period_count #(
    .DATA_BIT(DATA_BIT)
  ) period_count (
    .clk_i         (clk_i),
    .rst_ni        (rst_ni),
    .freq_pattern_i(freq_reg),
    .slow_period_i (slow_period_reg),
    .fast_period_i (fast_period_reg),
    .bit_count_0_i (channel_bit_count[0]),
    .bit_count_1_i (channel_bit_count[1]),
    .bit_count_2_i (channel_bit_count[2]),
    .bit_count_3_i (channel_bit_count[3]),
    .bit_count_4_i (channel_bit_count[4]),
    .bit_count_5_i (channel_bit_count[5]),
    .bit_count_6_i (channel_bit_count[6]),
    .bit_count_7_i (channel_bit_count[7]),
    .bit_count_8_i (channel_bit_count[8]),
    .bit_count_9_i (channel_bit_count[9]),
    .bit_count_10_i (channel_bit_count[10]),
    .bit_count_11_i (channel_bit_count[11]),
    .bit_count_12_i (channel_bit_count[12]),
    .bit_count_13_i (channel_bit_count[13]),
    .bit_count_14_i (channel_bit_count[14]),
    .bit_count_15_i (channel_bit_count[15]),
    .period_0_o (channel_period[0]),
    .period_1_o (channel_period[1]),
    .period_2_o (channel_period[2]),
    .period_3_o (channel_period[3]),
    .period_4_o (channel_period[4]),
    .period_5_o (channel_period[5]),
    .period_6_o (channel_period[6]),
    .period_7_o (channel_period[7]),
    .period_8_o (channel_period[8]),
    .period_9_o (channel_period[9]),
    .period_10_o (channel_period[10]),
    .period_11_o (channel_period[11]),
    .period_12_o (channel_period[12]),
    .period_13_o (channel_period[13]),
    .period_14_o (channel_period[14]),
    .period_15_o (channel_period[15])
  );

  // Use generate loop to create instances
  genvar j;
  generate for (j = 0; j < OUTPUT_NUM; j = j + 1'b1)
    begin: channel
      serial_out #(
      .DATA_BIT          (DATA_BIT)
      ) entity (
        .clk_i           (clk_i),
        .rst_ni          (rst_ni),
        .start_i         (start_tick[j]),
        .enable_i        (channel_enable[j]),
        .stop_i          (stop),
        .idle_i          (channel_idle[j]),
        .mode_i          (channel_mode[j]), // one-shot, repeat
        .amount_i        (channel_amount[j]),
        .output_pattern_i(output_reg),
        .period_i        (channel_period[j]),
        .repeat_i        (channel_repeat[j]),
        .addr_i          (addr_reg),
        .update_data_i   (channel_update_data[j]),
        .bit_count_o     (channel_bit_count[j]),
        .serial_out_o    (serial_out_o[j]), // idle state is low
        .done_tick_o     ()
      );
    end
  endgenerate

endmodule
