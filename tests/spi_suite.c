#include <stdint.h>
#include <stdio.h>
#include <stdbool.h>

#include "greatest.h"
#include "spi_suite.h"

#include "spi.h"

static uint32_t some_gpio_port = 0xFFFFFFFF;


TEST test_write_spi_gpio_pins_high(unsigned int pin)
{
	uint32_t init_val = 0x10000000;
	some_gpio_port = init_val;
	assert_spi_pin(&some_gpio_port, pin);
	ASSERT_EQ(some_gpio_port, (uint32_t) init_val | (1 << pin));
	PASS();
}

TEST test_write_spi_gpio_pins_low(unsigned int pin)
{
	uint32_t init_val = 0x1000FFFF;
	some_gpio_port = init_val;
	deassert_spi_pin(&some_gpio_port, pin);
	ASSERT_EQ(some_gpio_port, (uint32_t) init_val & ~(1 << pin));
	PASS();
}

TEST test_snprintf_return_val(bool sn_error)
{
	ASSERT_FALSE(sn_error);
	PASS();
}

void test_all_valid_gpio_pins_set_high(void)
{
	for (int i = 0; i < 16; ++i) {
		char test_suffix[5];
		int sn = snprintf(test_suffix, 4, "%u", i);
		bool sn_error = (sn > 5) || (sn < 0);
		greatest_set_test_suffix((const char*) &test_suffix);
		RUN_TEST1(test_snprintf_return_val, sn_error);
		greatest_set_test_suffix((const char*) &test_suffix);
		RUN_TEST1(test_write_spi_gpio_pins_high, i);
	}
}

void test_all_valid_gpio_pins_set_low(void)
{
	for (int i = 0; i < 16; ++i) {
		char test_suffix[5];
		int sn = snprintf(test_suffix, 4, "%u", i);
		bool sn_error = (sn > 5) || (sn < 0);
		greatest_set_test_suffix((const char*) &test_suffix);
		RUN_TEST1(test_snprintf_return_val, sn_error);
		greatest_set_test_suffix((const char*) &test_suffix);
		RUN_TEST1(test_write_spi_gpio_pins_low, i);
	}
}

SUITE(spi_driver)
{
	// looped test
	test_all_valid_gpio_pins_set_high();
	test_all_valid_gpio_pins_set_low();
}

