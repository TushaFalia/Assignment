export SHELL=/bin/bash

ROOT_DIR:=$(CURDIR)
BUILD_DIR:=$(ROOT_DIR)/build
LOG_DIR:=$(ROOT_DIR)/log

GUI:=0
ifeq ($(GUI),0)
	XSIM_CMD += -runall
else
	XSIM_CMD += -gui
endif

XVLOG_CMD += -sv
XVLOG_CMD += -i $(ROOT_DIR)/include
XVLOG_CMD += $(shell find $(ROOT_DIR)/APB-UART-TOP -name "*.sv")
#XVLOG_CMD += $(shell find $(ROOT_DIR)/APB-UART-TOP -name "*.sv")

$(BUILD_DIR) $(LOG_DIR):
	@mkdir -p $@
	@echo "*" > $@/.gitignore

.PHONY: clean
clean:
	@rm -rf $(BUILD_DIR) $(LOG_DIR)

.PHONY: all
all:
ifeq ($(TOP),)
	@echo "Error: TOP module is not specified." && exit 1
endif
	@make -s clean
	@make -s $(BUILD_DIR) $(LOG_DIR)
	@cd $(BUILD_DIR) && xvlog $(XVLOG_CMD) -log $(LOG_DIR)/xvlog_$(shell date +%Y%m%d_%H%M%S).log
	@cd $(BUILD_DIR) && xelab -debug all $(TOP) -s snap_$(TOP) -log $(LOG_DIR)/xelab_$(TOP)$(shell date +%Y%m%d%H%M%S).log
	@cd $(BUILD_DIR) && xsim snap_$(TOP) $(XSIM_CMD) -log $(LOG_DIR)/xsim_$(TOP)$(shell date +%Y%m%d%H%M%S).log
