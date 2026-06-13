build:
	@echo "Creating build directory..."
	@mkdir -p build
	@echo "*" > build/.gitignore 

.PHONY: run
run_1:
	@make -s build
	@cd build && xvlog -sv ../Practice/regif_tb.sv # xvlog is for linux system,and xvlog.exe for windows
	@cd build && xelab regif_tb -s simulation
	@cd build && xsim simulation -runall

.PHONY: clean
clean:
	@rm -rf build
	@echo "Cleaned build directory."