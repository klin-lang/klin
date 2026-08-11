/* Hand-written C twin of main.kl (issue 028 overhead check).
 * Same two tasks, same stacks/prios, same PA5 toggle MMIO as machine_stm32,
 * same vTaskDelay / xTaskCreate / vTaskStartScheduler — no Klin runtime.
 */
#include "FreeRTOS.h"
#include "task.h"

#include <stdint.h>

/* STM32F411 GPIOA + RCC AHB1ENR — same addresses as machine_stm32 Pin. */
#define RCC_AHB1ENR (*(volatile uint32_t *)0x40023830u)
#define GPIOA_MODER (*(volatile uint32_t *)0x40020000u)
#define GPIOA_ODR   (*(volatile uint32_t *)0x40020014u)

static void pa5_init_out(void) {
    RCC_AHB1ENR |= (1u << 0);
    GPIOA_MODER = (GPIOA_MODER & ~(3u << 10)) | (1u << 10);
}

static void pa5_toggle(void) {
    GPIOA_ODR ^= (1u << 5);
}

void task_blink(void *arg) {
    (void)arg;
    pa5_init_out();
    for (;;) {
        pa5_toggle();
        vTaskDelay(200);
    }
}

void task_heartbeat(void *arg) {
    (void)arg;
    for (;;) {
        vTaskDelay(1000);
    }
}

int main(void) {
    TaskHandle_t blink_handle = NULL;
    TaskHandle_t heartbeat_handle = NULL;
    xTaskCreate(task_blink, "blink", 512, NULL, 2, &blink_handle);
    xTaskCreate(task_heartbeat, "heartbeat", 256, NULL, 1, &heartbeat_handle);
    vTaskStartScheduler();
    for (;;) {
    }
    return 0;
}
