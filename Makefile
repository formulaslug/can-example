# The name of your project (used to name the compiled .hex file)
TARGET := $(notdir $(CURDIR))

# The Teensy version to use: 30, 31, or LC
TEENSY := 31

# Set to 24000000, 48000000, or 96000000 to set CPU core speed
TEENSY_CORE_SPEED := 48000000

# path location for Teensy 3 core
COREPATH := $(CURDIR)/src/fs-0-core/core

# path location for Arduino libraries
LIBRARYPATH := $(CURDIR)/src/fs-0-core/libs

# CPPFLAGS = compiler options for C and C++
CPPFLAGS := -Wall -Os -s -mthumb -ffunction-sections -fdata-sections -nostdlib -MMD -DUSB_SERIAL -DTEENSYDUINO=128 -DF_CPU=$(TEENSY_CORE_SPEED) -I$(COREPATH) -I$(LIBRARYPATH)

CFLAGS :=
CXXFLAGS := -std=c++1y -felide-constructors -fno-exceptions -fno-rtti -flto
LDFLAGS := -Os -Wl,--gc-sections,--defsym=__rtc_localtime=0 -mthumb -flto

# Additional libraries to link
LIBS := -lm

BUILDDIR := build

# Compiler options specific to Teensy version
ifeq ($(TEENSY), 30)
    CPPFLAGS += -D__MK20DX128__ -mcpu=cortex-m4
    LDSCRIPT := $(COREPATH)/mk20dx128.ld
    LDFLAGS += -mcpu=cortex-m4 -T$(LDSCRIPT)
else
    ifeq ($(TEENSY), 31)
        CPPFLAGS += -D__MK20DX256__ -mcpu=cortex-m4
        LDSCRIPT := $(COREPATH)/mk20dx256.ld
        LDFLAGS += -mcpu=cortex-m4 -T$(LDSCRIPT)
    else
        ifeq ($(TEENSY), LC)
            CPPFLAGS += -D__MKL26Z64__ -mcpu=cortex-m0plus
            LDSCRIPT := $(COREPATH)/mkl26z64.ld
            LDFLAGS += -mcpu=cortex-m0plus -T$(LDSCRIPT)
            LIBS += -larm_cortexM0l_math
        else
            $(error Invalid setting for TEENSY)
        endif
    endif
endif

# Names for the compiler programs
CC := arm-none-eabi-gcc
CXX := arm-none-eabi-g++
OBJCOPY := arm-none-eabi-objcopy
SIZE := arm-none-eabi-size

# Make does not offer a recursive wildcard function, so here's one:
rwildcard=$(wildcard $1$2) $(foreach dir,$(wildcard $1*),$(call rwildcard,$(dir)/,$2))

# Automatically create lists of the sources and objects
C_FILES := $(call rwildcard,src/,*.c)
CPP_FILES := $(call rwildcard,src/,*.cpp)
OBJS := $(addprefix $(BUILDDIR)/,$(C_FILES:.c=.o) $(CPP_FILES:.cpp=.o))

.PHONY: all
all: $(TARGET).hex

.PHONY: upload
upload: $(TARGET).hex
	teensy_loader_cli -mmcu=mk20dx256 -s -w $<

$(BUILDDIR)/%.o: %.c
	@echo "[CC] $<"
	@mkdir -p "$(dir $@)"
ifdef VERBOSE
	$(CC) $(CPPFLAGS) $(CFLAGS) -o "$@" -c "$<"
else
	@$(CC) $(CPPFLAGS) $(CFLAGS) -o "$@" -c "$<"
endif

$(BUILDDIR)/%.o: %.cpp
	@echo "[CXX] $<"
	@mkdir -p "$(dir $@)"
ifdef VERBOSE
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o "$@" -c "$<"
else
	@$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o "$@" -c "$<"
endif

$(TARGET).elf: $(OBJS) $(LDSCRIPT)
	@echo "[LD] $@"
ifdef VERBOSE
	$(CC) $(LDFLAGS) -o "$@" $(OBJS) $(LIBS)
else
	@$(CC) $(LDFLAGS) -o "$@" $(OBJS) $(LIBS)
endif

%.hex: %.elf
	@echo "[HEX] $@"
ifdef VERBOSE
	$(SIZE) "$<"
	$(OBJCOPY) -O ihex -R .eeprom "$<" "$@"
else
	@$(SIZE) "$<"
	@$(OBJCOPY) -O ihex -R .eeprom "$<" "$@"
endif

# Compiler-generated dependency info
-include $(OBJS:.o=.d)

.PHONY: clean
clean:
ifdef VERBOSE
	-$(RM) -r "$(BUILDDIR)"
	-$(RM) "$(TARGET).elf" "$(TARGET).hex"
else
	-@$(RM) -r "$(BUILDDIR)"
	-@$(RM) "$(TARGET).elf" "$(TARGET).hex"
endif
