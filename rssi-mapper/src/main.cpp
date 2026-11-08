#include <Arduino.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <esp_wifi.h>
#ifdef MAPPER_LEFT
#include <WebServer.h>
#include <esp_wifi_ap_get_sta_list.h>
#include "dashboard.h"
#endif

namespace {
constexpr char ssid[] = "FESWAVE-RSSI";
constexpr char password[] = "feswave-test";
constexpr uint16_t reportPort = 39810;
constexpr uint32_t freshMs = 2500;
constexpr size_t capacity = 8;
using Mac = uint8_t[6];

struct Reading {
  Mac mac;
  int16_t quarterDbm;  // Fixed point keeps smoothing cheap in the Wi-Fi callback.
  uint32_t seen;
  bool valid;
};

struct ReportEntry {
  Mac mac;
  int16_t quarterDbm;
  uint16_t ageMs;
};

struct Report {
  uint32_t signature;
  ReportEntry entries[capacity];
  uint8_t count;
};

constexpr uint32_t signature = 0x46575231;
Reading local[capacity]{};
Mac ap{};
portMUX_TYPE radioLock = portMUX_INITIALIZER_UNLOCKED;
WiFiUDP udp;

Reading &slotFor(Reading (&table)[capacity], const uint8_t *mac, uint32_t now) {
  Reading *oldest = &table[0];
  for (auto &r : table) {
    if (r.valid && memcmp(r.mac, mac, 6) == 0) return r;
    if (!r.valid || (oldest->valid && now - r.seen > now - oldest->seen)) oldest = &r;
  }
  return *oldest;
}

void observe(void *buffer, wifi_promiscuous_pkt_type_t kind) {
  if (kind != WIFI_PKT_DATA) return;
  const auto *pkt = static_cast<const wifi_promiscuous_pkt_t *>(buffer);
  const auto *p = pkt->payload;
  // ToDS only, data or QoS data. Addr1 is the AP, Addr2 the transmitting phone.
  if (pkt->rx_ctrl.sig_len < 28 || (p[1] & 3) != 1 ||
      (p[0] != 0x08 && p[0] != 0x88)) return;
  const uint32_t now = millis();
  portENTER_CRITICAL(&radioLock);
  if (memcmp(p + 4, ap, 6) == 0) {
    auto &r = slotFor(local, p + 10, now);
    int value = pkt->rx_ctrl.rssi * 4;
    if (r.valid && now - r.seen < freshMs && memcmp(r.mac, p + 10, 6) == 0)
      value = (3 * r.quarterDbm + value) / 4;
    memcpy(r.mac, p + 10, 6);
    r.quarterDbm = value;
    r.seen = now;
    r.valid = true;
  }
  portEXIT_CRITICAL(&radioLock);
}

void startRadio(const uint8_t *bssid) {
  portENTER_CRITICAL(&radioLock);
  memcpy(ap, bssid, 6);
  memset(local, 0, sizeof(local));
  portEXIT_CRITICAL(&radioLock);
  wifi_promiscuous_filter_t filter{};
  filter.filter_mask = WIFI_PROMIS_FILTER_MASK_DATA;
  ESP_ERROR_CHECK(esp_wifi_set_promiscuous_filter(&filter));
  ESP_ERROR_CHECK(esp_wifi_set_promiscuous_rx_cb(observe));
  ESP_ERROR_CHECK(esp_wifi_set_promiscuous(true));
}

#ifdef MAPPER_LEFT
WebServer web(80);
Reading right[capacity]{};
bool heardRight = false;
uint32_t lastReport = 0;

void receiveReport() {
  int size = udp.parsePacket();
  if (!size) return;
  Report report{};
  if (size != sizeof(report)) {
    udp.clear();
    return;
  }
  if (udp.read(reinterpret_cast<uint8_t *>(&report), sizeof(report)) != sizeof(report) ||
      report.signature != signature || report.count > capacity) return;
  lastReport = millis();
  heardRight = true;
  for (size_t i = 0; i < report.count; ++i) {
    const auto &e = report.entries[i];
    if (e.ageMs >= freshMs) continue;
    auto &r = slotFor(right, e.mac, lastReport);
    memcpy(r.mac, e.mac, 6);
    r.quarterDbm = e.quarterDbm;
    r.seen = lastReport - e.ageMs;
    r.valid = true;
  }
}

bool requestMac(Mac &mac) {
  wifi_sta_list_t stations{};
  wifi_sta_mac_ip_list_t clients{};
  if (esp_wifi_ap_get_sta_list(&stations) != ESP_OK ||
      esp_wifi_ap_get_sta_list_with_ip(&stations, &clients) != ESP_OK) return false;
  for (int i = 0; i < clients.num; ++i) {
    if (IPAddress(clients.sta[i].ip.addr) == web.client().remoteIP()) {
      memcpy(mac, clients.sta[i].mac, 6);
      return true;
    }
  }
  return false;
}

String freshValue(const Reading (&table)[capacity], const Mac &mac, uint32_t now) {
  for (const auto &r : table)
    if (r.valid && memcmp(r.mac, mac, 6) == 0 && now - r.seen < freshMs)
      return String(r.quarterDbm / 4.0, 1);
  return "null";
}

void sendMeasurement() {
  // The venue app runs on a PC on this AP, or on localhost via adb reverse.
  const String origin = web.header("Origin");
  if (origin == "http://localhost:3000" || origin == "http://127.0.0.1:3000" ||
      (origin.startsWith("http://192.168.4.") && origin.endsWith(":3000") &&
       origin == "http://192.168.4." + String(origin.substring(17).toInt()) + ":3000")) {
    web.sendHeader("Access-Control-Allow-Origin", origin);
    web.sendHeader("Vary", "Origin");
  }
  Mac mac{};
  web.sendHeader("Cache-Control", "no-store");
  if (!requestMac(mac)) {
    web.send(503, "text/plain", "Waiting for DHCP");
    return;
  }
  Reading snapshot[capacity];
  portENTER_CRITICAL(&radioLock);
  memcpy(snapshot, local, sizeof(local));
  portEXIT_CRITICAL(&radioLock);
  uint32_t now = millis();
  String json = "{\"left\":" + freshValue(snapshot, mac, now) +
                ",\"right\":" + freshValue(right, mac, now) +
                ",\"online\":" + (heardRight && now - lastReport < freshMs ? "true}" : "false}");
  const String place = web.arg("place");
  if (place == "L" || place == "C" || place == "R") {
    const unsigned long session = strtoul(web.arg("session").c_str(), nullptr, 16);
    Serial.printf("SAMPLE,%lu,%lx,%ld,%s,%.2f,%s\n", (unsigned long)now, session,
                  web.arg("trial").toInt(), place.c_str(), web.arg("bias").toFloat(), json.c_str());
  }
  web.send(200, "application/json", json);
}
#else
bool listening = false;
uint32_t lastSend = 0;

void reportReadings() {
  if (WiFi.status() != WL_CONNECTED) {
    listening = false;
    return;
  }
  if (!listening) {
    startRadio(WiFi.BSSID());
    WiFi.setSleep(false);
    listening = true;
    Serial.println("Connected to left receiver");
  }
  if (millis() - lastSend < 400) return;
  Report report{};
  report.signature = signature;
  portENTER_CRITICAL(&radioLock);
  lastSend = millis();
  for (const auto &r : local) {
    uint32_t age = lastSend - r.seen;
    if (!r.valid || age >= freshMs) continue;
    auto &e = report.entries[report.count++];
    memcpy(e.mac, r.mac, 6);
    e.quarterDbm = r.quarterDbm;
    e.ageMs = age;
  }
  portEXIT_CRITICAL(&radioLock);
  if (udp.beginPacket(WiFi.gatewayIP(), reportPort)) {
    udp.write(reinterpret_cast<const uint8_t *>(&report), sizeof(report));
    udp.endPacket();
  }
}
#endif
}  // namespace

void setup() {
  Serial.begin(115200);
  WiFi.persistent(false);
#ifdef MAPPER_LEFT
  WiFi.mode(WIFI_AP);
  if (!WiFi.softAP(ssid, password, 6) || !udp.begin(reportPort)) {
    Serial.println("AP or UDP startup failed");
    delay(2000);
    ESP.restart();
  }
  Mac bssid;
  WiFi.softAPmacAddress(bssid);
  startRadio(bssid);
  const char *headers[] = {"Origin"};
  web.collectHeaders(headers, 1);
  web.on("/", HTTP_GET, [] { web.send_P(200, "text/html; charset=utf-8", dashboard); });
  web.on("/api/me", HTTP_GET, sendMeasurement);
  web.begin();
  Serial.printf("Left receiver: http://%s/\n", WiFi.softAPIP().toString().c_str());
#else
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(ssid, password);
  Serial.println("Right receiver: joining FESWAVE-RSSI");
#endif
}

void loop() {
#ifdef MAPPER_LEFT
  receiveReport();
  web.handleClient();
#else
  reportReadings();
#endif
  delay(1);
}
