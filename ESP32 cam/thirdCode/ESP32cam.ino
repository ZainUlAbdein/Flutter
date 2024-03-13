#include "esp_camera.h"
#define CAMERA_MODEL_AI_THINKER
#include "camera_pins.h"
#include "BluetoothSerial.h"

BluetoothSerial SerialBT;

void setup() {
  Serial.begin(115200);
  initBT();
  initCamera();
}

void initBT(){
  if(!SerialBT.begin("ESP32CAM-CLASSIC-BT")){
    Serial.println("An error occurred initializing Bluetooth");
    ESP.restart();
  }else{
    Serial.println("Bluetooth initialized");
  }

  Serial.println("The device started, now you can pair it with bluetooth");
  // digitalWrite(FLASH_GPIO_NUM, HIGH);
}

void loop() {
  if (SerialBT.available()) {
    String stringRead = SerialBT.readStringUntil('\n');
    int paramInt = stringRead.toInt() - 48;
    Serial.printf("paramInt: %d\n", paramInt);
    setCameraParam(paramInt);
  }
}

void writeSerialBT(camera_fb_t *fb){
  SerialBT.write(fb->buf, fb->len);
  SerialBT.flush();
}

void initCamera(){
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  //extras
  // config.grab_mode = CAMERA_GRAB_LATEST;

  if(psramFound()){
    config.frame_size = FRAMESIZE_UXGA;
    // config.jpeg_quality = 10;
    config.jpeg_quality = 12;
    config.fb_count = 1;
    // config.fb_count = 2;
  } else {
    config.frame_size = FRAMESIZE_SVGA;
    config.jpeg_quality = 12;
    config.fb_count = 1;
  }

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x", err);
    ESP.restart();
  }
  pinMode(FLASH_GPIO_NUM, OUTPUT);
}

void setCameraParam(int paramInt){
  sensor_t *s = esp_camera_sensor_get();
  switch(paramInt){
    case 4:
      s->set_framesize(s, FRAMESIZE_UXGA);
    break;

    case 3:
      s->set_framesize(s, FRAMESIZE_SXGA);
    break;

    case 2:
      s->set_framesize(s, FRAMESIZE_XGA);
    break;

    case 1:
      s->set_framesize(s, FRAMESIZE_SVGA);
    break;

    case 0:
    default:
      s->set_framesize(s, FRAMESIZE_VGA);
    break;
  }
  digitalWrite(FLASH_GPIO_NUM, HIGH);
  capture();
  digitalWrite(FLASH_GPIO_NUM, LOW);
}

void capture(){
  // camera_fb_t *fb = NULL;
  // fb = esp_camera_fb_get();

  //extra
  camera_fb_t * fb = NULL;
  fb = esp_camera_fb_get();
  esp_camera_fb_return(fb); // dispose the buffered image
  fb = NULL; // reset to capture errors
  fb = esp_camera_fb_get(); // get fresh image

  if(!fb){
    esp_camera_fb_return(fb);
    return;
  }

  if(fb->format != PIXFORMAT_JPEG){
    return;
  }

  writeSerialBT(fb);
  esp_camera_fb_return(fb);
}
