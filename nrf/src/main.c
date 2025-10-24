#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <sht31d.h>
#include <zephyr/drivers/gpio.h>

#include <zephyr/bluetooth/bluetooth.h>
#include <zephyr/bluetooth/conn.h>
#include <zephyr/bluetooth/gatt.h>
#include <zephyr/bluetooth/uuid.h>

#define SLEEP_TIME_MS   1000
#define RELAY_NODE DT_NODELABEL(relay0)

static const struct gpio_dt_spec relay = GPIO_DT_SPEC_GET(RELAY_NODE, gpios);
LOG_MODULE_REGISTER(ble_test);
typedef struct { float temp; float hum; } rh_sample_t;
volatile bool ble_ready = false;
rh_sample_t sample;
static uint16_t humidity_fixed = 0;
static uint8_t mcu_command = 0;  // 0 = Off, 1 = On


static const struct bt_data ad[] = {
        BT_DATA_BYTES(BT_DATA_FLAGS, (BT_LE_AD_GENERAL | BT_LE_AD_NO_BREDR)),
        BT_DATA_BYTES(BT_DATA_UUID16_ALL, BT_UUID_16_ENCODE(BT_UUID_ESS_VAL))
};
static ssize_t read_humidity(struct bt_conn *conn,
                             const struct bt_gatt_attr *attr,
                             void *buf, uint16_t len, uint16_t offset) {
                                
//     humidity_fixed = (uint16_t) roundf(sample.hum * 100.0f);
    return bt_gatt_attr_read(conn, attr, buf, len, offset, &humidity_fixed, sizeof(humidity_fixed));
}

static ssize_t write_command(struct bt_conn *conn,
                             const struct bt_gatt_attr *attr,
                             const void *buf,
                             uint16_t len,
                             uint16_t offset,
                             uint8_t flags) {
    if (len >= 1) {
        mcu_command = ((uint8_t *)buf)[0];
        printk("📩 Received command: %u\n", mcu_command);

        if (mcu_command == 1) {
            // Turn on device logic
            gpio_pin_set_dt(&relay, 0);
            k_msleep(1000);
            gpio_pin_set_dt(&relay, 1);
            printk("Device turned ON\n");
        } else {
            // Turn off device logic
            gpio_pin_set_dt(&relay, 0);
            k_msleep(3000);
            gpio_pin_set_dt(&relay, 1);
            printk("Device turned OFF\n");
        }
    }

    return len;
}

BT_GATT_SERVICE_DEFINE( ess_srv, 
                        BT_GATT_PRIMARY_SERVICE(BT_UUID_ESS),
                        BT_GATT_CHARACTERISTIC(BT_UUID_HUMIDITY, BT_GATT_CHRC_READ | BT_GATT_CHRC_NOTIFY, BT_GATT_PERM_READ, read_humidity, NULL, &humidity_fixed),
                        BT_GATT_CCC(NULL, BT_GATT_PERM_READ | BT_GATT_PERM_WRITE),
                        BT_GATT_CHARACTERISTIC(BT_UUID_DECLARE_16(0x2A56), // Custom command UUID
                                                BT_GATT_CHRC_WRITE_WITHOUT_RESP,
                                                BT_GATT_PERM_WRITE,
                                                NULL, write_command, &mcu_command)
                       );

void bt_ready(int err){
        if(err) {
                LOG_ERR("bt enable return %d", err);
        }
        LOG_INF("bt ready!\n");
        ble_ready = true;
}

int init_ble(void){
        LOG_INF("Init BLE");
        int err;
        err = bt_enable(bt_ready);
        if(err) {
                LOG_ERR("bt_enable failed (err %d)", err);
                return err;
        }
        return 0;
}

int main(void)
{       
        init_ble();
        while(!ble_ready) {
                LOG_INF("BLE stack not ready yet");
                k_msleep(100);
        }
        LOG_INF("BLE stack ready");
        int err;
        err = bt_le_adv_start(BT_LE_ADV_CONN_NAME, ad, ARRAY_SIZE(ad), NULL, 0);
        if (err) {
                printk("Advertising failed to start (err %d)\n", err);
                return 0;
        }
        gpio_pin_configure_dt(&relay, GPIO_OUTPUT_ACTIVE);
        while (1) {
                if (SHT31_ReadTempHum(&sample.temp, &sample.hum) == 0) {
                        humidity_fixed    = (uint16_t)roundf(sample.hum * 100.0f);
                        bt_gatt_notify(NULL, &ess_srv.attrs[1], &humidity_fixed, sizeof(humidity_fixed));
                        printf("Temp : %.1f, Hum : %.1f%%\n", sample.temp, sample.hum);
                }
                k_msleep(SLEEP_TIME_MS);
        }
}
