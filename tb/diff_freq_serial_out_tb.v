/* Filename : diff_freq_serial_out_tb.v
 * Simulator: ModelSim - Intel FPGA Edition vsim 2020.1
 *
 * Testbench of diff_freq_serial_out.
 */

`timescale 1ns / 100ps
`include "parameter.vh"
`include "../rtl/user_cmd.vh"

module diff_freq_serial_out_tb ();

  // task parameter
  localparam ONE_SHOT_MODE = 2'b00;
  localparam CONTINUE_MODE = 2'b01;
  localparam REPEAT_MODE   = 2'b10;
  localparam DISABLE       = 1'b0;
  localparam ENABLE        = 1'b1;
  localparam IDLE_LOW      = 1'b0;
  localparam IDLE_HIGH     = 1'b1;

  // Signal declaration
  reg clk   = 0;
  reg rst_n = 0;

  // diff_freq_serial_out signal
  wire [`OUTPUT_NUM-1:0] serial_out_o;
  wire serial_out0_o  = serial_out_o[0]; // idle state is low
  wire serial_out1_o  = serial_out_o[1];
  wire serial_out2_o  = serial_out_o[2];
  wire serial_out3_o  = serial_out_o[3];
  wire serial_out4_o  = serial_out_o[4];
  wire serial_out5_o  = serial_out_o[5];
  wire serial_out6_o  = serial_out_o[6];
  wire serial_out7_o  = serial_out_o[7];
  wire serial_out8_o  = serial_out_o[8];
  wire serial_out9_o  = serial_out_o[9];
  wire serial_out10_o = serial_out_o[10];
  wire serial_out11_o = serial_out_o[11];
  wire serial_out12_o = serial_out_o[12];
  wire serial_out13_o = serial_out_o[13];
  wire serial_out14_o = serial_out_o[14];
  wire serial_out15_o = serial_out_o[15];

  // UART signal
  reg  tb_RxSerial;
  wire tb_TxSerial;

  // rx output port
  wire       tb_rx_done;
  wire       tb_tx_done;
  wire [7:0] tb_received_data;

  // system clock generator
  always #(`SYS_PERIOD_NS/2) clk = ~clk;

  initial begin
    #0;
    clk   = 1'b0;
    rst_n = 1'b0;

    #5;
    rst_n = 1'b1;
    #(`SYS_PERIOD_NS/2);
  end

  diff_freq_serial_out #(
    .DATA_BIT       (`DATA_BIT),
    .OUTPUT_NUM     (`OUTPUT_NUM),
    .SLOW_PERIOD    (`DEFAULT_SLOW_PERIOD),
    .FAST_PERIOD    (`DEFAULT_FAST_PERIOD)
  ) serial_out_unit (
    .clk_i          (clk),
    .rst_ni         (rst_n),
    .data_i         (tb_received_data),
    .rx_done_tick_i (tb_rx_done),
    .serial_out_o   (serial_out_o) // idle state is low
  );

  UART #(
    .SYS_CLK       (`SYS_CLK),
    .BAUD_RATE     (`BAUD_RATE),
    .DATA_BITS     (`UART_DATA_BIT),
    .STOP_BIT      (`UART_STOP_BIT)
  ) DUT_uart (
    .clk_i         (clk),
    .rst_ni        (rst_n),
    //rx interface
    .rx_i          (tb_RxSerial),
    .rx_done_tick_o(tb_rx_done),
    .rx_data_o     (tb_received_data),
    //tx interface
    .tx_start_i    (tb_rx_done),
    .tx_data_i     (tb_received_data),
    .tx_o          (tb_TxSerial),
    .tx_done_tick_o(tb_tx_done)
  );

  reg [7:0] slow_period = 8'h14;
  reg [7:0] fast_period = 8'h5;
  reg [`DATA_BIT-1:0] freq_pattern = `DATA_BIT'h0000_0000;
  reg [`DATA_BIT-1:0] data_pattern = `DATA_BIT'h5500_5500;

  initial begin
    @(posedge rst_n);       // wait for finish reset
    // update frequency
    // UPDATE_FREQ(2, freq_pattern);
    // UPDATE_PERIOD(slow_period, fast_period);
    // UPDATE_REPEAT(15, 3);
    UPDATE_DATA(0,  3, data_pattern, IDLE_LOW, ONE_SHOT_MODE, ENABLE);
    // UPDATE_DATA(1,  1, data_pattern, IDLE_LOW, REPEAT_MODE, ENABLE);
    // UPDATE_DATA(2,  2, data_pattern, IDLE_LOW, ONE_SHOT_MODE, ENABLE);
    // UPDATE_DATA(3,  3, data_pattern, IDLE_LOW, REPEAT_MODE, ENABLE);
    // UPDATE_DATA(4,  0, data_pattern, IDLE_LOW, ONE_SHOT_MODE, ENABLE);
    // UPDATE_DATA(5,  1, data_pattern, IDLE_LOW, ONE_SHOT_MODE, ENABLE);
    // UPDATE_DATA(6,  2, data_pattern, IDLE_LOW, ONE_SHOT_MODE, ENABLE);
    // UPDATE_DATA(7,  3, data_pattern, IDLE_LOW, ONE_SHOT_MODE, ENABLE);
    // UPDATE_DATA(8,  0, data_pattern, IDLE_LOW, REPEAT_MODE, ENABLE);
    // UPDATE_DATA(9,  1, data_pattern, IDLE_LOW, ONE_SHOT_MODE, ENABLE);
    // UPDATE_DATA(10, 2, data_pattern, IDLE_LOW, ONE_SHOT_MODE, ENABLE);
    // UPDATE_DATA(11, 3, data_pattern, IDLE_LOW, ONE_SHOT_MODE, ENABLE);
    // UPDATE_DATA(12, 2, data_pattern, IDLE_LOW, ONE_SHOT_MODE, ENABLE);
    // UPDATE_DATA(13, 2, data_pattern, IDLE_HIGH, ONE_SHOT_MODE, ENABLE);
    // UPDATE_DATA(14, 3, data_pattern, IDLE_HIGH, REPEAT_MODE, ENABLE);
    // UPDATE_DATA(15, 3, data_pattern, IDLE_HIGH, REPEAT_MODE, ENABLE);
    UPDATE_GLOBAL(1);

    //$finish;
  end

  //To check RX module
  task UART_WRITE_BYTE;
    input [`UART_DATA_BIT-1:0] WRITE_DATA;
    integer i;
    begin
      //Send Start Bit
      tb_RxSerial = 1'b0;
      #(`UART_BIT_PERIOD);

      //Send Data Byte
      for (i = 0; i < `UART_DATA_BIT; i = i + 1'b1)
        begin
          tb_RxSerial = WRITE_DATA[i];
          #(`UART_BIT_PERIOD);
        end

      //Send Stop Bit
      tb_RxSerial = 1'b1;
      #(`UART_BIT_PERIOD);
    end
  endtask

  task UPDATE_DATA;
    input [7:0] channel;
    input [7:0] amount;
    input [`DATA_BIT-1:0] data_pattern;
    input reg idle;
    input reg [1:0] mode;
    input reg en;
    integer i;
    begin
      // command
      UART_WRITE_BYTE(`CMD_DATA);
      UART_WRITE_BYTE(channel);
      UART_WRITE_BYTE(amount);
      // data pattern
      for (i = 0; i < amount + 1'b1; i = i + 1'b1)
        begin
          UART_WRITE_BYTE(data_pattern[7:0]); // transmit LSB first
          data_pattern = data_pattern[`DATA_BIT-1:8];  // right-shift 8-bit
        end
      // control byte
      UART_WRITE_BYTE(`CMD_CTRL);
      UART_WRITE_BYTE(channel);
      UART_WRITE_BYTE({4'h0, idle, mode, en});
    end
  endtask

  task UPDATE_FREQ;
    input [7:0] amount;
    input [`DATA_BIT-1:0] freq_pattern;
    integer i;
    begin
      // command
      UART_WRITE_BYTE(`CMD_FREQ);
      // amount
      UART_WRITE_BYTE(amount);
      // freq pattern
      for (i = 0; i < amount + 1'b1; i = i + 1'b1)
        begin
          UART_WRITE_BYTE(freq_pattern[7:0]); // transmit LSB first
          freq_pattern = freq_pattern[`DATA_BIT-1:8];  // right-shift 8-bit
        end
    end
  endtask

  task UPDATE_PERIOD;
    input [7:0] slow_period;
    input [7:0] fast_period;
    begin
      // command
      UART_WRITE_BYTE(`CMD_PERIOD);
      UART_WRITE_BYTE(slow_period);
      UART_WRITE_BYTE(fast_period);
    end
  endtask

  task UPDATE_REPEAT;
    input [7:0] channel;
    input [7:0] repeat_times;
    begin
      // command
      UART_WRITE_BYTE(`CMD_REPEAT);
      UART_WRITE_BYTE(channel);
      UART_WRITE_BYTE(repeat_times);
    end
  endtask

  task UPDATE_GLOBAL;
    input stop;
    begin
      // command
      UART_WRITE_BYTE(`CMD_GLOBAL);
      UART_WRITE_BYTE({7'h0, stop});
    end
  endtask

endmodule
