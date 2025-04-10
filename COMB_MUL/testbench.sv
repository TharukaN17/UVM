`include "uvm_macros.svh"
import uvm_pkg::*;

class mul_transaction extends uvm_sequence_item;
  
  rand bit [3:0] a, b;
  bit [7:0] y;
  
  function new(string name="mul_transaction");
    super.new(name);
  endfunction
  
  `uvm_object_utils_begin(mul_transaction);
    `uvm_field_int(a, UVM_DEFAULT)
    `uvm_field_int(b, UVM_DEFAULT)
    `uvm_field_int(y, UVM_DEFAULT)
  `uvm_object_utils_end
  
endclass

class mul_sequence extends uvm_sequence#(mul_transaction);
  `uvm_object_utils(mul_sequence)
  
  mul_transaction tr;
  
  function new(string name="mul_sequence");
    super.new(name);
  endfunction
  
  virtual task body();
    tr = mul_transaction::type_id::create("tr");
    repeat(15) begin
      start_item(tr);
      if(!tr.randomize()) 
        `uvm_error("SEQ", "Randomization failed.")
      finish_item(tr);
    end
  endtask

endclass

class mul_driver extends uvm_driver#(mul_transaction);
  `uvm_component_utils(mul_driver)
  
  virtual mul_if vif;
  mul_transaction tr;
  
  function new(string name="mul_driver", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual mul_if)::get(this, "", "vif", vif))
      `uvm_error("DRV", "Unable to access interface.")
  endfunction
      
  virtual task run_phase(uvm_phase phase);
    tr = mul_transaction::type_id::create("tr");
    forever begin
      seq_item_port.get_next_item(tr);
      vif.a <= tr.a;
      vif.b <= tr.b;
      `uvm_info("DRV", $sformatf("a: %0d, b: %0d, y: %0d", tr.a, tr.b, tr.y), UVM_NONE)
      seq_item_port.item_done();
      #20;
    end
  endtask
    
endclass
    
class mul_monitor extends uvm_monitor;
  `uvm_component_utils(mul_monitor)
  
  virtual mul_if vif;
  mul_transaction tr;
  uvm_analysis_port#(mul_transaction) analysis_port;
  
  function new(string name="mul_monitor", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual mul_if)::get(this, "", "vif", vif))
      `uvm_error("MON", "Unable to access interface.")
    analysis_port = new("analysis_port", this);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    tr = mul_transaction::type_id::create("tr");
    forever begin
      #20;
      tr.a = vif.a;
      tr.b = vif.b;
      tr.y = vif.y;
      `uvm_info("MON", $sformatf("a: %0d, b: %0d, y: %0d", tr.a, tr.b, tr.y), UVM_NONE)
      analysis_port.write(tr);
    end
  endtask
    
endclass
    
class mul_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(mul_scoreboard)
  
  mul_transaction tr;
  uvm_analysis_imp#(mul_transaction, mul_scoreboard) analysis_imp;
  
  function new(string name="mul_scoreboard", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_imp = new("analysis_imp", this);
  endfunction
  
  virtual function void write(mul_transaction t);
    $cast(tr, t.clone());
    if(tr.y == tr.a * tr.b)
      `uvm_info("SCB", "Test passed.", UVM_NONE)
    else
      `uvm_error("SCB", "Test failed.")
  endfunction
  
endclass
      
class mul_agent extends uvm_agent;
  `uvm_component_utils(mul_agent)
  
  mul_driver drv;
  mul_monitor mon;
  uvm_sequencer#(mul_transaction) seqr;
  
  function new(string name="mul_agent", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv = mul_driver::type_id::create("drv", this);
    mon = mul_monitor::type_id::create("mon", this);
    seqr = uvm_sequencer#(mul_transaction)::type_id::create("seqr", this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction
        
endclass
    
class mul_env extends uvm_env;
  `uvm_component_utils(mul_env)
  
  mul_agent agnt;
  mul_scoreboard scb;
  
  function new(string name="mul_env", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agnt = mul_agent::type_id::create("agnt", this);
    scb = mul_scoreboard::type_id::create("scb", this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agnt.mon.analysis_port.connect(scb.analysis_imp);
  endfunction

endclass
    
class mul_test extends uvm_test;
  `uvm_component_utils(mul_test)
  
  mul_env env;
  mul_sequence seq;
  
  function new(string name="mul_test", uvm_component parent=null);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = mul_env::type_id::create("env", this);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    seq = mul_sequence::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.agnt.seqr);
    #50;
    phase.drop_objection(this);
  endtask
      
endclass
    
module mul_tb();
  
  mul_if vif();
  mul dut(.a(vif.a), .b(vif.b), .y(vif.y));
  
  initial begin
    uvm_config_db#(virtual mul_if)::set(null, "uvm_test_top.env.agnt*", "vif", vif);
    run_test("mul_test");
  end
endmodule
