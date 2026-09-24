# Meta Earbud Background

[English](README.md) | **Türkçe**

Seçtiğiniz Bluetooth kulaklık bağlandığında Meta gözlükte **Pause** ve **Battery saver** ayarlarını açan KernelSU modülü. Kulaklık bağlantısı kesilince önceki ayarlar geri yüklenir. Telefon ekranı kapalıyken, uygulamaya dokunmadan arka planda çalışır.

Modül gözlük sesini kulaklığa **aktarmıyor**.

## Gereksinimler

- KernelSU bulunan root erişimli Android arm64 telefon ve birincil Android kullanıcı profili.
- Meta AI **289.0.0.25.162**, versionCode **968902270**. Modül uygulamanın dahili metotlarına bağlı olduğundan diğer sürümler kabul edilmez.
- Meta AI'ye bağlı gözlük ve **A2DP** bağlantısı kurmuş Bluetooth kulaklık. Yalnızca eşleştirme yeterli değildir.

Kodda sabit kulaklık markası, modeli, hesap veya cihaz adresi yoktur. Her kurulum kendi kulaklık ve gözlüğünü seçer. Zygisk ve LSPosed gerekmez.

Modül deneyseldir. Referans platform Android 16'dır; farklı ROM, gözlük yazılımı ve kulaklık kombinasyonlarında uyumluluk garanti edilmez.

## Kurulum ve yapılandırma

1. [Releases](../../releases) sayfasından `meta-earbud-background-v1.1.0-public.zip` dosyasını indirin.
2. **KernelSU → Modüller → Yükle** yoluyla kurun ve telefonu yeniden başlatın.
3. Root terminali açın veya `adb shell` ardından `su` çalıştırın.
4. Kurulumu başlatın:

```sh
sh /data/adb/modules/meta-earbud-background/configure.sh
```

5. Sorulduğunda kendi kulaklığınızın Bluetooth adresini ve gözlüğünüzün Bluetooth / Meta DeviceRecord adresini girin. İlk iki soruda iki noktayla ayrılmış adresleri; üçüncü soruda gözlüğün Bluetooth'ta görünen tam adını girin (seri numarasını değil).
6. Yeniden başlatın. Gözlük bağlıyken kulaklığı bağlayıp iki ayarın açıldığını; kulaklığı ayırınca önceki değerlerin geri geldiğini kontrol edin.

ZIP yapılandırılana kadar pasiftir. Adresler yalnızca telefonda girilir; indirilen pakette bulunmaz. Kurulum için kaynak kod derlemek gerekmez. Adres bulma ve sürüm değiştirme ayrıntıları [kurulum rehberindedir](docs/release-install.md).

## Davranış

| Olay | Sonuç |
| --- | --- |
| Seçilen kulaklık bağlanır | Önceki ayarlar saklanır; Pause ve Battery saver açılır. |
| Seçilen kulaklık ayrılır | Önceki ayarlar geri yüklenir. |
| Başka kulaklık bağlanır | Dikkate alınmaz. |
| Ekran kapalıdır | Arka planda çalışmaya devam eder. |
| Gözlük bağlı değil | Modül dinleyicisi durur; Meta başlatılmaz ve aracı yüklenmez. |
| Meta AI sürümü desteklenmez | Adaptör etkinleştirilmez. |

Bağlantı değişiklikleri yaklaşık 2,5 saniye bekletilir. Battery saver eşitlemesi yaklaşık 10 saniye sürebilir. Pause sekiz saat için açılır ve kulaklık bağlı kaldıkça saatte bir yenilenir; mevcut daha uzun süre korunur. Battery saver, uyandırma sözcüğü üzerindeki etkisi dahil Meta'nın normal kısıtlamalarını uygular.

Bağlantı yokken kontrol 60, bağlıyken 30 saniyedir; uyandırma alarmı kullanılmaz. Yeniden bağlanma bir kontrol aralığı, cihaz uyuyorsa daha uzun sürebilir. Bluetooth biçimi okunamazsa yeni iş başlatılmaz; mevcut dinleyici kesin kopma görülene kadar tutulur. Meta'nın kendi işleri zorla durdurulmaz; sıfır RAM/güç tüketimi vaat edilmez.

## Durum ve sorun giderme

KernelSU'da modülün **İşlem / Action** düğmesini kullanın veya:

```sh
adb shell su -c 'cat /data/adb/meta-earbud-background/status'
```

- `WAITING_FOR_CONFIGURATION`: yapılandırmayı çalıştırıp yeniden başlatın.
- `WAITING_FOR_GLASSES`: gözlüğün açık ve Meta AI'ye bağlı olduğunu doğrulayın.
- `HEADSET_CONNECTED=false`: seçilen kulaklığın adresini ve A2DP bağlantısını kontrol edin.
- `VERIFY_FAILED`: gözlük/kulaklığı yeniden bağlayıp Meta AI'deki ayarları kontrol edin.
- `RESTORE_POINT_WRITE_FAILED`: önceki ayarlar kaydedilemedi; o denemede gözlüğün ayarları değiştirilmedi.
- `Unsupported Meta AI version`: kurulu Meta AI sürümü desteklenmiyor.

Yapılandırılmış betikleri ve cihaz günlüklerini kendi telefonunuzda tutun; cihaz kimlikleri veya kullanım ayrıntıları içerebilirler. Meta AI verilerini temizlemek, saklanan geri yükleme durumunu siler.

## Güncelleme, cihaz değiştirme veya kaldırma

Gözlük bağlı kalırken seçilen kulaklığı ayırın ve önceki ayarların geri geldiğini doğrulayın. Yeni sürümü kurmadan önce eski modülü kaldırıp telefonu yeniden başlatın; yeni kurulumu tekrar yapılandırın. Kurulum betiği mevcut yapılandırmanın üzerine yazmaz.

Modülü durdurmak veya kaldırmak gözlük ayarlarını kendiliğinden geri yüklemez. Sürüm değiştirirken eski adaptörün bellekte kalmaması için yeniden başlatma gereklidir. Gözlük bağlantısı yokken geri yükleme doğrulanamaz.

## Test durumu

v1.1.0 ön sürümdür. Temel kişisel denetleyici Nothing Phone (1) / crDroid Android 16 üzerinde gözlük bağlı değilken doğrulandı. Genel paket yapılandırma/paketleme ve Android kabuk politika testlerinden geçirilir; genel paketin temiz kurulumla fiziksel yeniden bağlanma/ayar geri yükleme testi henüz tamamlanmadı. Ölçülmüş pil kazancı iddia edilmiyor.

## Kaynaktan derleme

Deponun **Code** menüsünden klonlama adresini alıp klonlayın, ardından:

```sh
cd meta-earbud-background
npm ci
python scripts/build.py
```

Gereksinimler: Node.js/npm, Python 3.10+ ve resmi Frida indirmesi için internet. Windows'ta Python komutu `py -3` olabilir. Android SDK ve Gradle gerekmez.

Derleme her zaman genel indirmeyle aynı türde, adres içermeyen şablon üretir. Yerel cihaz yapılandırmasını okumaz. Çıktı: `dist/meta-earbud-background-v1.1.0-public.zip`.

İndirilmiş resmi Frida arşivi `--inject-xz /path/to/frida-inject-17.18.0-android-arm64.xz` ile verilebilir. Paketlenmeden önce sabit SHA-256 değeri doğrulanır. Üçüncü taraf bildirimleri [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) dosyasındadır.

Bu bağımsız bir projedir; Meta veya KernelSU ile resmi bağlantısı yoktur.
