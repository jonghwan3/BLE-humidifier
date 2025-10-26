## BLE-Humidity-Controller (nRF52840)
BLE-Enabled Humidifier on nRF52840 board using Zephyr and Flutter.
lets a user set a target RH and automatically toggles the humidifier to keep RH within a ±1% hysteresis band around that target.

### What it does
- Shows target and live humidity on an iOS device (BLE-communication)
- Lets the user adjust target humidity and turn on/off via BLE
- Reads humidity from an SHT31-D sensor over I²C.
- Controls the humidifier by simulating a front-panel button press through a 4N25 optocoupler (GPIO-driven), ensuring electrical isolation.

### Demo (with PCB)
https://github.com/user-attachments/assets/4c73f07e-5874-40eb-8b59-4fa3f24a8939

### Demo (without PCB)
https://github.com/user-attachments/assets/2d19b58f-f283-4380-a724-1ac33203506f

### Design decisions
- Optocoupler (4N25): Provides galvanic isolation between the STM32 (3.3 V logic) and the humidifier’s circuit, protecting the MCU from voltage spikes or unknown transients.
- ±1% hysteresis band: Prevents rapid toggling near the setpoint, reducing actuator stress and ensuring stable humidity control.

