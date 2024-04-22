TOOLSET = arm-none-eabi
CC := $(TOOLSET)-gcc
AS := $(TOOLSET)-as
AR := $(TOOLSET)-ar
GDB := $(TOOLSET)-gdb
SIZE := $(TOOLSET)-size
OBJCOPY := $(TOOLSET)-objcopy

FLASH := st-flash

SRCDIR = src
INCDIR = inc
LIBDIR = lib
OBJDIR = .obj
DEPDIR = .deps

BASECMSISDIR := $(LIBDIR)/cmsis
STMHALDIR := $(BASECMSISDIR)/stm32g4xx_hal_driver
STMHALINC := $(STMHALDIR)/Inc
STMCMSISDIR := $(BASECMSISDIR)/cmsis_device_g4
STMCMSISINC := $(STMCMSISDIR)/Include
ARMCMSISDIR := $(BASECMSISDIR)/CMSIS_6/CMSIS/Core
ARMCMSISINC := $(ARMCMSISDIR)/Include
BSPDIR := $(BASECMSISDIR)/stm32g4xx-nucleo-bsp
CMSISMODULES := $(STMHALDIR) $(STMCMSISDIR) $(BSPDIR) $(BASECMSISDIR)/CMSIS_6

ST7789LIBDIR := $(LIBDIR)/st7789_generic
ST7789LIBINC := $(ST7789LIBDIR)/inc

COMMON_CFLAGS = -Wall -Wextra -std=c11 -g3 -Os
CMSIS_CPPFLAGS := -DUSE_HAL_DRIVER -DUSE_NUCLEO_32 -DSTM32G431xx
CMSIS_CPPFLAGS += -I $(STMHALINC) -I $(STMCMSISINC) -I $(ARMCMSISINC) -I $(BSPDIR)

CPUFLAGS = -mcpu=cortex-m4 -mthumb
FPUFLAGS = -mfloat-abi=hard -mfpu=fpv4-sp-d16

AFLAGS := -D --warn $(CPUFLAGS) -g
CPPFLAGS := -I $(INCDIR) $(CMSIS_CPPFLAGS) -I $(ST7789LIBINC)
CFLAGS := $(CPUFLAGS) $(FPUFLAGS) $(COMMON_CFLAGS) -ffunction-sections -fdata-sections
LDSCRIPT := STM32G431KBTX_FLASH.ld
LDFLAGS := -T $(LDSCRIPT) -Wl,--start-group -lc -lgcc -lnosys -Wl,--end-group
LDFLAGS += -Wl,-Map=main.map,--cref
LDLIBS :=
DEPFLAGS = -MT $@ -MMD -MP -MF $(@:$(OBJDIR)/%.o=$(DEPDIR)/%.d)

SRCS := $(wildcard $(SRCDIR)/*.c)
SRCOBJS := $(SRCS:%.c=$(OBJDIR)/%.o)
SRCDEPS := $(SRCS:%.c=$(DEPDIR)/%.d)
STARTUPFILE := $(STMCMSISDIR)/Source/Templates/gcc/startup_stm32g431xx.s
STARTUPOBJ := $(STARTUPFILE:%.s=$(OBJDIR)/%.o)
SYSFILE := $(STMCMSISDIR)/Source/Templates/system_stm32g4xx.c
SYSOBJ := $(SYSFILE:%.c=$(OBJDIR)/%.o)
STMHALSRCS := $(STMHALDIR)/Src/stm32g4xx_hal.c
STMHALSRCS += $(STMHALDIR)/Src/stm32g4xx_hal_cortex.c
STMHALSRCS += $(STMHALDIR)/Src/stm32g4xx_hal_gpio.c
STMHALOBJS := $(STMHALSRCS:%.c=$(OBJDIR)/%.o)

ST7789LIBSRCS := $(wildcard $(ST7789LIBDIR)/src/*.c)
ST7789LIBOBJS := $(ST7789LIBSRCS:%.c=$(OBJDIR)/%.o)

TARGET = stm32g4_main
ST7789LIBTARGET = lib_st7789_generic
SPILIBTESTTARGET = spi_tests
ST7789LIBTESTTARGET = st7789_tests

TESTCC := gcc
TESTSIZE := size

TESTDIR = tests
MOCKLIBDIR = lib/fff
TESTLIBDIR = lib/greatest
TESTOBJDIR := $(OBJDIR)/$(TESTDIR)
ST7789LIBTESTDIR := $(ST7789LIBDIR)/tests
TESTCPPFLAGS := -I $(INCDIR) -I $(TESTLIBDIR) -I $(TESTDIR) -I $(MOCKLIBDIR) -I $(ST7789LIBINC)
TESTCFLAGS := $(COMMON_CFLAGS) $(CMSIS_CPPFLAGS)

SPILIBTESTSRCS := $(ST7789LIBTESTDIR)/spi_suite.c $(ST7789LIBTESTDIR)/spi_main.c
SPILIBTESTSRCS += $(ST7789LIBDIR)/$(SRCDIR)/spi.c
SPILIBTESTOBJS := $(SPILIBTESTSRCS:%.c=$(TESTOBJDIR)/%.o)

ST7789LIBTESTSRCS := $(ST7789LIBTESTDIR)/st7789_suite.c $(ST7789LIBTESTDIR)/st7789_main.c
ST7789LIBTESTSRCS += $(ST7789LIBDIR)/$(SRCDIR)/st7789.c
ST7789LIBTESTOBJS := $(ST7789LIBTESTSRCS:%.c=$(TESTOBJDIR)/%.o)


.PHONY: all clean tests srcdepdir cmsis_modules_git_update test_modules_git_update \
flash-erase flash-write flash-backup
all: $(TARGET).elf $(TARGET).bin $(ST7789LIBTARGET).a
tests: $(SPILIBTESTTARGET).elf $(ST7789LIBTESTTARGET).elf


flash-backup:
	$(FLASH) read BIN_BACKUP.bin 0x08000000 0x20000

flash-write: $(TARGET).bin
	$(FLASH) --flash=128k write $< 0x08000000

flash-erase:
	$(FLASH) erase


$(ST7789LIBTARGET).a: $(ST7789LIBOBJS)
	@echo "Creating static st7789 library"
	$(AR) rcs $@ $^
	$(SIZE) $@

$(OBJDIR)/$(ST7789LIBDIR)/%.o: $(ST7789LIBDIR)/%.c
	@echo "Creating st7789 library objects"
	@mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(SYSOBJ): $(SYSFILE)
	@echo "Creating system object"
	@mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(STARTUPOBJ): $(STARTUPFILE)
	@echo "Creating startup object"
	@mkdir -p $(@D)
	$(AS) $(AFLAGS) $< -o $@

# Satisfy make, no rule needed for target, is only a prerequisite
$(STARTUPFILE):
$(SYSFILE):

$(OBJDIR)/$(STMHALDIR)/%.o: $(STMHALDIR)/%.c
	@echo "Creating HAL objects"
	@mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

cmsis_modules_git_update:
	@echo "Initializing/updating cmsis submodules"
	git submodule update --init --remote $(CMSISMODULES)


$(TARGET).bin: $(TARGET).elf
	@echo "Creating binary image"
	$(OBJCOPY) -O binary $^ $@

$(TARGET).elf: $(SRCOBJS) $(STARTUPOBJ) $(SYSOBJ) $(STMHALOBJS) $(ST7789LIBTARGET).a | cmsis_modules_git_update
	@echo "Linking objects"
	$(CC) $(LDFLAGS) $(LDLIBS) $(CPUFLAGS) $(FPUFLAGS) $^ -o $@
	$(SIZE) $@

$(OBJDIR)/$(SRCDIR)/%.o: $(SRCDIR)/%.c | srcdepdir
	@echo "Creating objects"
	@mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(DEPFLAGS) -c $< -o $@

srcdepdir :
	@mkdir -p $(DEPDIR)/$(SRCDIR)

$(SRCDEPS):

test_modules_git_update:
	@echo "Initializing/updating greatest submodule"
	git submodule update --init --remote $(LIBDIR)/greatest $(LIBDIR)/fff

# Unit test builds
$(SPILIBTESTTARGET).elf: $(SPILIBTESTOBJS) | test_modules_git_update
	@echo "Linking test objects"
	$(TESTCC) $(TESTLDFLAGS) $(TESTLDLIBS) $^ -o $@
	$(TESTSIZE) $@

$(ST7789LIBTESTTARGET).elf: $(ST7789LIBTESTOBJS) | test_modules_git_update
	@echo "Linking test objects"
	$(TESTCC) $(TESTLDFLAGS) $(TESTLDLIBS) $^ -o $@
	$(TESTSIZE) $@

$(TESTOBJDIR)/%.o: %.c
	@echo "Creating test objects"
	@mkdir -p $(@D)
	$(TESTCC) $(TESTCPPFLAGS) $(TESTCFLAGS) -c $< -o $@


clean:
	@echo "Cleaning build"
	-$(RM) $(TARGET).{elf,bin} $(ST7789LIBTARGET).a $(SPILIBTESTTARGET).elf $(ST7789LIBTESTTARGET).elf
	-$(RM) -rf $(OBJDIR) $(DEPDIR)

-include $(wildcard $(SRCDEPS))
