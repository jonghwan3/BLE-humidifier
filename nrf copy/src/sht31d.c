/*
 * sht31d.c
 *
 *  Created on: Sep 4, 2025
 *      Author: Jonghwan Park
 */
#include "sht31d.h"
#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/i2c.h>

#define I2C_NODE DT_NODELABEL(i2c0)
static const struct device *i2c0_dev = DEVICE_DT_GET(I2C_NODE);

int SHT31_ReadTempHum(float *temperature, float *humidity) {
    int ret;
//    uint8_t cmd[2] = {0x24, 0x00};   // high repeatability, no clock stretching
	uint8_t cmd[2] = {0x2C, 0x06};   // high repeatability, no clock stretching
    uint8_t data[6];

    if (!device_is_ready(i2c0_dev)) {
        printf("I2C bus not ready\n");
        return -1;
    }

    // Transmit command
    ret = i2c_write(i2c0_dev, cmd, sizeof(cmd), SHT31D_I2C_ADDR);
    if (ret < 0) {
        printf("I2C write failed: %d\n", ret);
        return -1;
    }

    // Wait ≥15ms (datasheet says 15ms typical)
    k_msleep(20);

    // Receive data
    ret = i2c_read(i2c0_dev, data, sizeof(data), SHT31D_I2C_ADDR);
    if (ret < 0) {
        printf("I2C read failed: %d\n", ret);
        return -2;
    }

    if (SHT31_CRC8(data, 2) != data[2] || SHT31_CRC8(data+3, 2) != data[5])
        return -3;

    uint16_t rawT  = (data[0] << 8) | data[1];
    uint16_t rawRH = (data[3] << 8) | data[4];

    *temperature = -45.0f + 175.0f * ((float) rawT / 65535.0f);
    *humidity    = 100.0f * ((float) rawRH / 65535.0f);

    return 0; // success
}

uint8_t SHT31_CRC8(const uint8_t *data, int len) {
    uint8_t crc = 0xFF;
    for (int i = 0; i < len; i++) {
        crc ^= data[i];
        for (int b = 0; b < 8; b++) {
            crc = (crc & 0x80) ? (crc << 1) ^ 0x31 : (crc << 1);
        }
    }
    return crc;
}


