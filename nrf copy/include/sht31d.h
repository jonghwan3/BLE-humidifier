/*
 * sht31d.h
 *
 *  Created on: Sep 4, 2025
 *      Author: Jonghwan Park
 */

#ifndef INC_SHT31D_H_
#define INC_SHT31D_H_ 101
#include <stdint.h>
#ifndef SHT31D_I2C_ADDR
#define SHT31D_I2C_ADDR			0x44
#endif


uint8_t SHT31_CRC8(const uint8_t *data, int len);

int SHT31_ReadTempHum(float *temperature, float *humidity);

#endif /* INC_SHT31D_H_ */
