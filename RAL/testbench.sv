`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_transaction extends uvm_sequence_item;
    `uvm_object_utils(apb_transaction)

    rand bit [31:0] paddr;
    rand bit [31:0] pwdata;
    bit [31:0] prdata;
    rand bit pwrite;

    function new(string name="apb_transaction");
        super.new(name);
    endfunction

    constraint c_addr {
        paddr inside {'h0, 'h4, 'h8, 'hc, 'h10};
    }
endclass

class apb_driver extends uvm_driver#(apb_transaction);
    `uvm_component_utils(apb_driver)

    apb_transaction tr;
    virtual top_if vif;

    function new(string name="apb_driver", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual top_if)::get(this, "", "vif", vif))
            `uvm_error("DRV", "Failed to access interface!")
    endfunction

    virtual task reset_dut();
        vif.presetn <= 0;
        vif.paddr  <= 0;
        vif.pwdata  <= 0;
        vif.pwrite  <= 0;
        vif.psel    <= 0;
        vif.penable <= 0;
        repeat(5) @(posedge vif.pclk);
        vif.presetn <= 1;
    endtask

    virtual task write();
        @(posedge vif.pclk);
        vif.paddr <= tr.paddr;
        vif.pwdata <= tr.pwdata;
        vif.psel   <= 1;
        vif.pwrite <= 1;
        @(posedge vif.pclk);
        vif.penable <= 1;
        @(posedge vif.pclk);
        vif.psel    <= 0;
        vif.penable <= 0;
    endtask

    virtual task read();
        @(posedge vif.pclk);
        vif.paddr  <= tr.paddr;
        vif.psel   <= 1;
        vif.pwrite <= 0;
        @(posedge vif.pclk);
        vif.penable <= 1;
        @(posedge vif.pclk);
        vif.psel    <= 0;
        vif.penable <= 0;
        tr.prdata = vif.prdata;
    endtask

    virtual task run_phase(uvm_phase phase);
        tr = apb_transaction::type_id::create("tr");
        reset_dut();
        forever begin
            seq_item_port.get_next_item(tr);
            if(tr.pwrite) write();
            else read();
            seq_item_port.item_done();
        end
    endtask
endclass

class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)

    apb_transaction tr;
    virtual top_if vif;
    uvm_analysis_port#(apb_transaction) a_port;

    function new(string name="apb_monitor", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual top_if)::get(this, "", "vif", vif))
            `uvm_error("MON", "Failed to access interface!")
        a_port = new("a_port", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        tr = apb_transaction::type_id::create("tr");
        forever begin
            @(posedge vif.pclk);
            if(vif.psel && vif.penable && vif.presetn) begin
                tr.paddr = vif.paddr;
                tr.pwrite = vif.pwrite;
                if(vif.pwrite) begin
                    tr.pwdata = vif.pwdata;
                    @(posedge vif.pclk);
                end 
                else begin
                    @(posedge vif.pclk);
                    tr.prdata = vif.prdata;
                end
            end
            a_port.write(tr);
        end
    endtask
endclass

class apb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(apb_scoreboard)

    apb_transaction tr;
    uvm_analysis_imp#(apb_transaction, apb_scoreboard) a_imp;

    bit [31:0] reg_arr [17];

    function new(string name="apb_scoreboard", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        a_imp = new("a_imp", this);
    endfunction

    virtual function void write(apb_transaction t);
        $cast(tr, t);
        if(tr.pwrite) begin
            reg_arr[tr.paddr] = tr.pwdata;
        end
        else begin
            if(tr.prdata == reg_arr[tr.paddr])
                `uvm_info("SCB", "Test passed!", UVM_NONE)
            else
                `uvm_error("SCB", "Test failed!")
        end
    endfunction
endclass

class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)

    apb_driver driver;
    apb_monitor monitor;
    uvm_sequencer#(apb_transaction) sequencer;

    function new(string name="apb_agent", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        driver    = apb_driver::type_id::create("driver", this);
        monitor   = apb_monitor::type_id::create("monitor", this);
        sequencer = uvm_sequencer#(apb_transaction)::type_id::create("sequencer", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
endclass

class cntrl_reg extends uvm_reg;
    `uvm_object_utils(cntrl_reg)

    rand uvm_reg_field cntrl;

    function new(string name="cntrl_reg");
        super.new(name, 4, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        cntrl = uvm_reg_field::type_id::create("cntrl");
        cntrl.configure(this, 4, 0, "RW", 0, 4'h0, 1, 1, 1);
    endfunction
endclass

class reg1_reg extends uvm_reg;
    `uvm_object_utils(reg1_reg)

    rand uvm_reg_field reg1;

    function new(string name="reg1_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        reg1 = uvm_reg_field::type_id::create("reg1");
      reg1.configure(this, 32, 0, "RW", 0, 32'h00000000, 1, 1, 1);
    endfunction
endclass

class reg2_reg extends uvm_reg;
    `uvm_object_utils(reg2_reg)

    rand uvm_reg_field reg2;

    function new(string name="reg2_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        reg2 = uvm_reg_field::type_id::create("reg2");
      reg2.configure(this, 32, 0, "RW", 0, 32'h00000000, 1, 1, 1);
    endfunction
endclass

class reg3_reg extends uvm_reg;
    `uvm_object_utils(reg3_reg)

    rand uvm_reg_field reg3;

    function new(string name="reg3_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        reg3 = uvm_reg_field::type_id::create("reg3");
      reg3.configure(this, 32, 0, "RW", 0, 32'h00000000, 1, 1, 1);
    endfunction
endclass

class reg4_reg extends uvm_reg;
    `uvm_object_utils(reg4_reg)

    rand uvm_reg_field reg4;

    function new(string name="reg4_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        reg4 = uvm_reg_field::type_id::create("reg4");
      reg4.configure(this, 32, 0, "RW", 0, 32'h00000000, 1, 1, 1);
    endfunction
endclass

class reg_block extends uvm_reg_block;
    `uvm_object_utils(reg_block)

    cntrl_reg cntrl_inst;
    reg1_reg reg1_inst;
    reg2_reg reg2_inst;
    reg3_reg reg3_inst;
    reg4_reg reg4_inst;

    function new(string name="reg_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        cntrl_inst = cntrl_reg::type_id::create("cntrl_inst");
        cntrl_inst.build();
        cntrl_inst.configure(this, null);

        reg1_inst = reg1_reg::type_id::create("reg1_inst");
        reg1_inst.build();
        reg1_inst.configure(this, null);

        reg2_inst = reg2_reg::type_id::create("reg2_inst");
        reg2_inst.build();
        reg2_inst.configure(this, null);

        reg3_inst = reg3_reg::type_id::create("reg3_inst");
        reg3_inst.build();
        reg3_inst.configure(this, null);

        reg4_inst = reg4_reg::type_id::create("reg4_inst");
        reg4_inst.build();
        reg4_inst.configure(this, null);

        default_map = create_map("default_map", 0, 4, UVM_LITTLE_ENDIAN, 0);
        default_map.add_reg(cntrl_inst, 'h0, "RW");
        default_map.add_reg(reg1_inst, 'h4, "RW");
        default_map.add_reg(reg2_inst, 'h8, "RW");
        default_map.add_reg(reg3_inst, 'hc, "RW");
        default_map.add_reg(reg4_inst, 'h10, "RW");

        lock_model();
    endfunction
endclass

class apb_adapter extends uvm_reg_adapter;
    `uvm_object_utils(apb_adapter)

    function new(string name="apb_adapter");
        super.new(name);
    endfunction

    function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        apb_transaction tr;
        tr = apb_transaction::type_id::create("tr");

        tr.pwrite = rw.kind == UVM_WRITE;
        tr.paddr = rw.addr;
        tr.pwdata = rw.data;

        return tr;
    endfunction

    function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        apb_transaction tr;
        $cast(tr, bus_item);

        rw.kind = tr.pwrite ? UVM_WRITE : UVM_READ;
        rw.addr = tr.paddr;
        rw.data = tr.pwrite ? tr.pwdata : tr.prdata;
        rw.status = UVM_IS_OK;
    endfunction
endclass

class apb_env extends uvm_env;
    `uvm_component_utils(apb_env)

    apb_agent agent;
    apb_scoreboard scoreboard;
    reg_block regmodel;
    apb_adapter adapter;
    uvm_reg_predictor#(apb_transaction) predictor;

    function new(string name="apb_env", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = apb_agent::type_id::create("agent", this);
        scoreboard = apb_scoreboard::type_id::create("scoreboard", this);

        regmodel = reg_block::type_id::create("regmodel");
        regmodel.build();

        adapter = apb_adapter::type_id::create("adapter");
        predictor = uvm_reg_predictor#(apb_transaction)::type_id::create("predictor", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.a_port.connect(scoreboard.a_imp);
        agent.monitor.a_port.connect(predictor.bus_in);

        regmodel.default_map.set_sequencer(agent.sequencer, adapter);
        regmodel.default_map.set_base_addr(0);

        predictor.map = regmodel.default_map;
        predictor.adapter = adapter;
    endfunction
endclass

class read_write_seqeunce extends uvm_sequence;
    `uvm_object_utils(read_write_seqeunce)

    reg_block regmodel;
    uvm_status_e status;
    bit [31:0] rd_data;

    function new(string name="read_write_seqeunce");
        super.new(name);
    endfunction

    virtual task body();
        for(int i=0; i<5; i++) begin
            regmodel.cntrl_inst.write(status, $urandom());
            regmodel.cntrl_inst.read(status, rd_data);
            regmodel.reg1_inst.write(status, $urandom());
            regmodel.reg1_inst.read(status, rd_data);
            regmodel.reg2_inst.write(status, $urandom());
            regmodel.reg2_inst.read(status, rd_data);
            regmodel.reg3_inst.write(status, $urandom());
            regmodel.reg3_inst.read(status, rd_data);
            regmodel.reg4_inst.write(status, $urandom());
            regmodel.reg4_inst.read(status, rd_data);
        end
    endtask
endclass

class apb_test extends uvm_test;
    `uvm_component_utils(apb_test)

    apb_env env;
    read_write_seqeunce seq;

    function new(string name="apb_test", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = apb_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        seq = read_write_seqeunce::type_id::create("seq");
        seq.regmodel = env.regmodel;
        phase.raise_objection(this);
        if(!seq.randomize())
            `uvm_error("TEST", "Randomization failed!")
        seq.start(env.agent.sequencer);
        phase.drop_objection(this);
        phase.phase_done.set_drain_time(this, 200);
    endtask
endclass

module apb_tb();
  	top_if vif();
    top dut(.pclk(vif.pclk), 
             .presetn(vif.presetn), 
             .paddr(vif.paddr), 
             .pwdata(vif.pwdata), 
             .pwrite(vif.pwrite), 
             .psel(vif.psel), 
             .penable(vif.penable),
             .prdata(vif.prdata));
    
    initial begin
        vif.pclk <= 0;
    end

    always #5 vif.pclk = ~vif.pclk;

    initial begin
        uvm_config_db#(virtual top_if)::set(null, "uvm_test_top.env.agent*", "vif", vif);
        run_test("apb_test");
    end
endmodule
