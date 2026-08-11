#include "stm32f411_regs.h"

void SysTick_Handler(void) {
  GPIOA_ODR_ODR5_toggle();
}

int main(void) {
  RCC_AHB1ENR_GPIOAEN_set(1);
  GPIOA_MODER_MODER5_write(GPIOA_MODER_MODER5_Output);
  STK_RVR_RELOAD_write(7999999);
  STK_CVR_CURRENT_write(0);
  STK_CSR_ENABLE_set(1);
  STK_CSR_TICKINT_set(1);
  STK_CSR_CLKSOURCE_set(1);
  while (1) {
    __asm volatile("wfi");
  }
}
