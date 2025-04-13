`include "uvm_macros.svh"
import uvm_pkg::*;

typedef enum bit [1:0] {reset_asserted=0, random_baud=1} oper_mode;

class clk_gen_transaction extends uvm_sequence_item;
  rand bit [16:0] baud;
  rand oper_mode oper;
  real tx_period;
  real rx_period;
  
  function new(string name="clk_gen_transaction");
    super.new(name);
  endfunction
  
  `uvm_object_utils_begin(clk_gen_transaction)
    `uvm_field_int(baud, UVM_DEFAULT)
    `uvm_field_enum(oper_mode,oper, UVM_DEFAULT)
    `uvm_field_real(tx_period, UVM_DEFAULT)
    `uvm_field_real(rx_period, UVM_DEFAULT)
  `uvm_object_utils_end
  
  constraint con_baud{
    baud inside {4800, 9600, 14400, 19200, 38400, 57600, 115200, 128000};
  };
endclass

class clk_gen_reset_sequence extends uvm_sequence#(clk_gen_transaction);
  `uvm_object_utils(clk_gen_reset_sequence)
  
  clk_gen_transaction tr;
  bit success;
  
  function new(string name="clk_gen_reset_sequence");
    super.new(name);
  endfunction
  
  virtual task body();
    tr = clk_gen_transaction::type_id::create("tr");
    repeat(5) begin
      start_item(tr);
      success = tr.randomize() with {oper == reset_asserted;};
      if(!success)
        `uvm_error("SEQ", "Randomization failed!")
      finish_item(tr);
    end
  endtask
endclass

class clk_gen_rand_baud_sequence extends uvm_sequence#(clk_gen_transaction);
  `uvm_object_utils(clk_gen_rand_baud_sequence)
  
  clk_gen_transaction tr;
  bit success;
  
  function new(string name="clk_gen_rand_baud_sequence");
    super.new(name);
  endfunction
  
  virtual task body();
    tr = clk_gen_transaction::type_id::create("tr");
    repeat(25) begin
      start_item(tr);
      success = tr.randomize() with {oper == random_baud;};
      if(!success)
        `uvm_error("SEQ", "Randomization failed!")
      finish_item(tr);
    end
  endtask
endclass

class clk_gen_driver extends uvm_driver#(clk_gen_transaction);
  `uvm_component_utils(clk_gen_driver)
  
  clk_gen_transaction tr;
  virtual clk_gen_if vif;
  
  function new(string name="clk_gen_driver", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual clk_gen_if)::get(this, "", "vif", vif))
      `uvm_error("DRV", "Unable to connect the interface!")
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    tr = clk_gen_transaction::type_id::create("tr");
    forever begin
      seq_item_port.get_next_item(tr);
      `uvm_info("DRV", $sformatf("rst: %0d, baud: %0d", !tr.oper, tr.baud), UVM_HIGH)
      if(tr.oper == reset_asserted) begin
        vif.rst <= 1;
        @(posedge vif.clk);
      end
      else begin
        vif.rst <= 0;
        vif.baud <= tr.baud;
        @(posedge vif.clk);
        repeat(2) @(posedge vif.tx_clk);
        repeat(2) @(posedge vif.rx_clk);
      end
      seq_item_port.item_done();
    end
  endtask
endclass
      
class clk_gen_monitor extends uvm_monitor;
  `uvm_component_utils(clk_gen_monitor)
  
  clk_gen_transaction tr;
  virtual clk_gen_if vif;
  uvm_analysis_port#(clk_gen_transaction) analysis_port;
  
  real tx_ton;
  real tx_toff;
  real rx_ton;
  real rx_toff;
  
  function new(string name="clk_gen_monitor", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual clk_gen_if)::get(this, "", "vif", vif))
      `uvm_error("MON", "Unable to connect the interface!")
    analysis_port = new("analysis_port", this);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    tr = clk_gen_transaction::type_id::create("tr");
    forever begin
      @(posedge vif.clk);
      if(vif.rst) begin
        tr.oper = reset_asserted;
        tx_ton = 0;
        rx_toff = 0;
      end
      else begin
        tr.oper = random_baud;
        tr.baud = vif.baud;
        @(posedge vif.tx_clk);
        tx_ton = $realtime;
        @(posedge vif.tx_clk);
        tx_toff = $realtime;
        @(posedge vif.rx_clk);
        rx_ton = $realtime;
        @(posedge vif.rx_clk);
        rx_toff = $realtime;
        tr.tx_period = tx_toff-tx_ton;
        tr.rx_period = rx_toff-rx_ton;
      end
      `uvm_info("MON", $sformatf("rst: %0d, baud: %0d", !tr.oper, tr.baud), UVM_HIGH)
      analysis_port.write(tr);
    end
  endtask
endclass
      
class clk_gen_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(clk_gen_scoreboard)
  
  clk_gen_transaction tr;
  uvm_analysis_imp#(clk_gen_transaction, clk_gen_scoreboard) analysis_imp;
  
  int tx_baud_count;
  int rx_baud_count;
  
  function new(string name="clk_gen_scoreboard", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_imp = new("analysis_imp", this);
  endfunction
  
  virtual function void write(clk_gen_transaction t);
    $cast(tr, t.clone());
    tx_baud_count = $rtoi(tr.tx_period/20);
    rx_baud_count = $rtoi(tr.rx_period/20);
    `uvm_info("SCB", $sformatf("rst: %0d, baud: %0d, tx_baud_count: %0d, rx_baud_count: %0d", !tr.oper, tr.baud, tx_baud_count, rx_baud_count), UVM_HIGH)
    if(tr.oper == reset_asserted) begin
      if(tx_baud_count == 0 && rx_baud_count == 0) `uvm_info("SCB", "Test passed!", UVM_NONE)
      else `uvm_error("SCB", "Test failed!")
    end
    else begin
      case(tr.baud)
        4800: begin
          if(tx_baud_count == 10416 && rx_baud_count == 650) `uvm_info("SCB", "Test passed!", UVM_NONE)
          else `uvm_error("SCB", "Test failed!")
        end
        9600: begin
          if(tx_baud_count == 5208 && rx_baud_count == 324) `uvm_info("SCB", "Test passed!", UVM_NONE)
          else `uvm_error("SCB", "Test failed!")
        end
        14400: begin
          if(tx_baud_count == 3472 && rx_baud_count == 216) `uvm_info("SCB", "Test passed!", UVM_NONE)
          else `uvm_error("SCB", "Test failed!")
        end
        19200: begin
          if(tx_baud_count == 2604 && rx_baud_count == 162) `uvm_info("SCB", "Test passed!", UVM_NONE)
          else `uvm_error("SCB", "Test failed!")
        end
        38400: begin
          if(tx_baud_count == 1302 && rx_baud_count == 80) `uvm_info("SCB", "Test passed!", UVM_NONE)
          else `uvm_error("SCB", "Test failed!")
        end
        57600: begin
          if(tx_baud_count == 868 && rx_baud_count == 54) `uvm_info("SCB", "Test passed!", UVM_NONE)
          else `uvm_error("SCB", "Test failed!")
        end
        115200: begin
          if(tx_baud_count == 434 && rx_baud_count == 26) `uvm_info("SCB", "Test passed!", UVM_NONE)
          else `uvm_error("SCB", "Test failed!")
        end
        128000: begin
          if(tx_baud_count == 392 && rx_baud_count == 24) `uvm_info("SCB", "Test passed!", UVM_NONE)
          else `uvm_error("SCB", "Test failed!")
        end
        default: begin
          `uvm_error("SCB", "Test failed! : Error in baud rate.")
        end
      endcase
    end
  endfunction
endclass

class clk_gen_agent extends uvm_agent;
  `uvm_component_utils(clk_gen_agent)
  
  clk_gen_driver drv;
  clk_gen_monitor mon;
  uvm_sequencer#(clk_gen_transaction) seqr;
  
  function new(string name="clk_gen_agent", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv = clk_gen_driver::type_id::create("drv", this);
    mon = clk_gen_monitor::type_id::create("mon", this);
    seqr = uvm_sequencer#(clk_gen_transaction)::type_id::create("seqr", this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction
endclass
        
class clk_gen_env extends uvm_env;
  `uvm_component_utils(clk_gen_env)
  
  clk_gen_agent agnt;
  clk_gen_scoreboard scb;
  
  function new(string name="clk_gen_env", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agnt = clk_gen_agent::type_id::create("agnt", this);
    scb = clk_gen_scoreboard::type_id::create("scb", this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agnt.mon.analysis_port.connect(scb.analysis_imp);
  endfunction
endclass
        
class clk_gen_test extends uvm_test;
  `uvm_component_utils(clk_gen_test)
  
  clk_gen_env env;
  clk_gen_reset_sequence reset_seq;
  clk_gen_rand_baud_sequence rand_baud_seq;
  
  function new(string name="clk_gen_test", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = clk_gen_env::type_id::create("env", this);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    reset_seq = clk_gen_reset_sequence::type_id::create("reset_seq");
    rand_baud_seq = clk_gen_rand_baud_sequence::type_id::create("rand_baud_seq");
    
    phase.raise_objection(this);
    reset_seq.start(env.agnt.seqr);
    rand_baud_seq.start(env.agnt.seqr);
    #20;
    phase.drop_objection(this);
  endtask
endclass
        
module clk_gen_tb();
  clk_gen_if vif();
  clk_gen dut(.clk(vif.clk), .rst(vif.rst), .baud(vif.baud), .tx_clk(vif.tx_clk), .rx_clk(vif.rx_clk));
  
  initial begin
    vif.clk <= 0;
  end
  
  always #10 vif.clk <= ~vif.clk;
    
  initial begin
    uvm_config_db#(virtual clk_gen_if)::set(null, "uvm_test_top.env.agnt*", "vif", vif);
    run_test("clk_gen_test");
  end
endmodule
