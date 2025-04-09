`include "uvm_macros.svh"
import uvm_pkg::*;

class dff_transaction extends uvm_sequence_item;
  rand bit din;
  bit dout;

  function new(string name="dff_transaction");
    super.new(name);
  endfunction

  `uvm_object_utils_begin(dff_transaction)
    `uvm_field_int(din, UVM_DEFAULT)
    `uvm_field_int(dout, UVM_DEFAULT)
  `uvm_object_utils_end

endclass

class dff_sequence extends uvm_sequence#(dff_transaction);
  `uvm_object_utils(dff_sequence)

  dff_transaction tr;

  function new(string name="dff_sequence");
    super.new(name);
  endfunction

  virtual task body();
    tr = dff_transaction::type_id::create("tr");
    repeat(10) begin
      start_item(tr);
      if(!tr.randomize())
        `uvm_error("SEQ", "Randomization failed!")
      `uvm_info("SEQ", $sformatf("din: %0d", tr.din), UVM_NONE)
      finish_item(tr);
    end
  endtask

endclass

class dff_driver extends uvm_driver#(dff_transaction);
  `uvm_component_utils(dff_driver)

  dff_transaction tr;
  virtual dff_if vif;

  function new(string name="dff_driver", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tr = dff_transaction::type_id::create("tr");
    if(!uvm_config_db#(virtual dff_if)::get(this, "", "vif", vif))
      `uvm_error("DRV", "Unable to access the interface.")
  endfunction

  virtual task reset_dut();
    vif.rst <= 1;
    vif.din <= 0;
    repeat(5) @(posedge vif.clk);
    vif.rst <= 0;
    `uvm_info("DRV", "Reset done.", UVM_NONE)
  endtask

  virtual task run_phase(uvm_phase phase);
    reset_dut();
    forever begin
      seq_item_port.get_next_item(tr);
      vif.din <= tr.din;
      seq_item_port.item_done();
      repeat(2) @(posedge vif.clk);
    end
  endtask

endclass

class dff_monitor extends uvm_monitor;
  `uvm_component_utils(dff_monitor)

  uvm_analysis_port#(dff_transaction) port;

  dff_transaction tr;
  virtual dff_if vif;

  function new(string name="dff_monitor", uvm_component parent=null);
    super.new(name, parent);
    port = new("port", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tr = dff_transaction::type_id::create("tr");
    if(!uvm_config_db#(virtual dff_if)::get(this, "", "vif", vif))
      `uvm_error("DRV", "Unable to access the interface.")
  endfunction

  virtual task run_phase(uvm_phase phase);
    @(negedge vif.rst);
    forever begin
      repeat(2) @(posedge vif.clk);
      tr.din = vif.din;
      tr.dout = vif.dout;
      `uvm_info("MON", $sformatf("dout: %0d", tr.dout), UVM_NONE)
      port.write(tr);
    end
  endtask

endclass

class dff_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(dff_scoreboard)

  uvm_analysis_imp#(dff_transaction, dff_scoreboard) imp;

  dff_transaction tr;

  function new(string name="dff_scoreboard", uvm_component parent=null);
    super.new(name, parent);
    imp = new("imp", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tr = dff_transaction::type_id::create("tr");
  endfunction

  virtual function void write(dff_transaction t);
    $cast(tr, t.clone());
    if(tr.din == tr.dout) `uvm_info("SCB", "Test Passed.", UVM_NONE)
    else `uvm_error("SCB", "Test Failed.")
  endfunction

endclass

class dff_agent extends uvm_agent;
  `uvm_component_utils(dff_agent)

  dff_driver drv;
  dff_monitor mon;
  uvm_sequencer#(dff_transaction) seqr;

  function new(string name="dff_agent", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv = dff_driver::type_id::create("drv", this);
    mon = dff_monitor::type_id::create("mon", this);
    seqr = uvm_sequencer#(dff_transaction)::type_id::create("seqr", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction

endclass

class dff_env extends uvm_env;
  `uvm_component_utils(dff_env)

  dff_scoreboard scb;
  dff_agent agnt;

  function new(string name="dff_env", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    scb = dff_scoreboard::type_id::create("scb", this);
    agnt = dff_agent::type_id::create("agnt", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agnt.mon.port.connect(scb.imp);
  endfunction

endclass

class dff_test extends uvm_test;
  `uvm_component_utils(dff_test)

  dff_env env;
  dff_sequence seq;

  function new(string name="dff_test", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = dff_env::type_id::create("env", this);
    seq = dff_sequence::type_id::create("seq");
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq.start(env.agnt.seqr);
    #50;
    phase.drop_objection(this);
  endtask

endclass

module dff_tb();

  dff_if vif();

  initial begin
    vif.clk = 0;
    vif.rst = 0;
  end

  always #10 vif.clk = ~vif.clk;

  dff dut(.clk(vif.clk), .rst(vif.rst), .din(vif.din), .dout(vif.dout));

  initial begin
    uvm_config_db#(virtual dff_if)::set(null, "uvm_test_top.env.agnt*", "vif", vif);
    run_test("dff_test");
  end

endmodule
