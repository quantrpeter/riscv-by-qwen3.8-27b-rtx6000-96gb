# ==============================================================================
# RV32I Soft Core - Verilator Build
# ==============================================================================

VERILATOR   := verilator
RTL_DIR     := rtl
TB_DIR      := tb
BUILD_DIR   := build

RTL_SRCS := $(wildcard $(RTL_DIR)/*.sv)
TB_SRCS  := $(wildcard $(TB_DIR)/*.sv)

TOP_MODULE  := tb_rv32_core
SIM_BINARY  := $(BUILD_DIR)/obj_dir/V$(TOP_MODULE)

.PHONY: all sim lint clean

all: $(SIM_BINARY)

$(SIM_BINARY): $(RTL_SRCS) $(TB_SRCS)
	@mkdir -p $(BUILD_DIR)
	$(VERILATOR) --binary \
		--timing \
		--trace \
		-Wno-fatal \
		--top-module $(TOP_MODULE) \
		-Mdir $(BUILD_DIR)/obj_dir \
		$(RTL_SRCS) $(TB_SRCS)

sim: $(SIM_BINARY)
	@echo "Running simulation..."
	./$(SIM_BINARY)

lint:
	$(VERILATOR) --lint-only \
		--timing \
		-Wno-fatal \
		--top-module rv32_core \
		$(RTL_SRCS)

clean:
	rm -rf $(BUILD_DIR)

$(SIM_BINARY): | $(BUILD_DIR)

$(BUILD_DIR):
	mkdir -p $@