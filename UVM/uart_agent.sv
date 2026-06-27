`ifndef _GUARD_BASE_TEST_SV_
`define _GUARD_BASE_TEST_SV_ 0

`include "component/apb_uart_env.sv"


class apb_agent extends uvm_agent;

  `uvm_component_utils(apb_agent)

  virtual apb_if apb_intf;

  function new(string name = "apb_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    sqr= apb_uart_env::type_id::create("sqr", this);
    dvr= apb_uart_env::type_id::create("dvr", this);
    mon= apb_uart_env::type_id::create("mon", this);
    vif= apb_uart_env::type_id::create("vif", this);

  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    

  endfunction

endclass

