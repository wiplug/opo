#ifndef OPOBASE_H
#define OPOBASE_H

#define CC2420_DEF_CHANNEL 24
#define CC2520_DEF_CHANNEL 24

typedef nx_struct opo_rec_msg {
    nx_uint8_t valid; //validates data read from flash
    nx_uint32_t range; // Range is given in micrometers to avoid decimals
    nx_uint32_t sequence; // Used to match nodes to the same broadcast
    nx_uint8_t o_id[6]; // ID from transmitter's (other node's) ds2411
    nx_int8_t rssi;
    nx_uint8_t tx_pwr;
    nx_uint8_t seconds;
    nx_uint8_t minutes;
    nx_uint8_t hours;
} opo_rec_t;

typedef nx_struct opo_base_msg {
    opo_rec_t rec;
    nx_uint8_t m_id[6];
} opo_bmsg_t;

typedef nx_struct opo_blink_base_msg {
    nx_uint8_t  m_id[6];
    nx_uint8_t  o_id[6];
    nx_uint32_t range;
} oblink_base_msg_t;

typedef nx_struct opo_visual_base_msg {
    nx_uint8_t  rx_id[6];
    nx_uint8_t  tx_id[6];
    nx_uint16_t ultrasonic_rf_dt;
    nx_uint16_t ultrasonic_wake_dt;
    nx_uint16_t ultrasonic_dt;
    nx_uint16_t full_time;
    nx_uint16_t seq;
    nx_uint16_t rx_fails;
    nx_uint16_t tx_fails;
} ovis_base_msg_t;

typedef nx_struct opo_rx_base_msg {
    nx_uint8_t  rx_id[8];
    nx_uint8_t  tx_id[8];
    nx_uint16_t rx_t_rf;
    nx_uint16_t rx_t_ultrasonic;
    nx_uint32_t tx_seq;
    nx_uint16_t rx_seq;
    nx_int8_t   rx_rssi;
    nx_uint8_t  rx_fail_count;
} opo_rx_base_msg_t;

typedef nx_struct opo_adc_msg {
    nx_uint16_t readings[6];
    nx_uint16_t times[6];
    nx_uint16_t rf_time;
} opo_adc_msg_t;

typedef nx_struct opo_flash_msg {
    nx_uint8_t sid[16];
    nx_uint8_t readBuffer[8];
    nx_uint8_t statusRegister;
} opo_flash_t;

typedef nx_struct opo_sht25_test_message {
    nx_uint16_t temp;
    nx_uint16_t rh;
} opo_sht25_test_msg_t;

typedef nx_struct opo_rtc_msg {
    nx_uint16_t full_time[8];
} opo_rtc_msg_t;

typedef nx_struct id_store {
    nx_uint16_t id;
    nx_uint32_t seed;
} id_store_t;

typedef nx_struct opo_flash_store_base_rf_msg {
    nx_uint16_t tx_id;
    nx_uint16_t rx_id;
    nx_uint16_t ultrasonic_rf_dt;
    nx_int8_t   rssi;
    nx_uint8_t  full_time[5];
    nx_uint32_t tx_seq;
    nx_uint16_t rx_fails;
} oflash_base_rf_msg_t;


typedef nx_struct opo_flash_reader_test_msg {
    nx_uint32_t base_time;
    nx_uint32_t current_time;
} oflash_reader_test_msg_t;


enum {
    OPO_DATA = 20,
    OPO_BLINK = 21,
    OPO_VISUAL_BASE = 22,
    OPO_RX_BASE = 23,
    OPO_ADC_BASE = 24,
    OPO_VISUAL_STORE_BASE = 25,
    OPO_RF_TEST = 26,
    OPO_FLASH_TEST = 27,
    OPO_SHT25_TEST = 28,
    OPO_RTC_TEST = 29,
    OPO_FLASH_STORE_BASE = 40,
    OPO_ID_WRITER_BASE = 41,
    OPO_FLASH_READER_BASE = 42,
    OPO_FLASH_READER_TEST = 43
};

#endif
