# VMware Lab Toolkit

```text
         ______  ____    ____    __  __  __          __  __  ______  ____    ______
 /'\_/`\/\  _  \/\  _`\ /\  _`\ /\ \/\ \/\ \        /\ \/\ \/\  _  \/\  _`\ /\__  _\
/\      \ \ \L\ \ \,\L\_\ \ \L\ \ \ \ \ \ \ \       \ \ \_\ \ \ \L\ \ \ \/\ \/_/\ \/
/\ \__\ \ \  __ \/_\__ \\ \ ,  /\ \ \ \ \ \ \  __   \ \  _  \ \  __ \ \ \ \ \ \ \ \
 \ \ \_/\ \ \ \/\ \/\ \L\ \ \ \\ \\ \ \_\ \ \ \L\ \   \ \ \ \ \ \/\ \ \ \_\ \ \_\ \__
  \ \_\\ \_\ \_\ \_\ `\____\ \_\ \_\ \_____\ \____/    \ \_\ \_\ \_\ \_\ \____/ /\_____\
   \/_/ \/_/\/_/\/_/\/_____/\/_/\/ /\/_____/\/___/      \/_/\/_/\/_/\/_/\/___/  \/_____/

 __    __  _____   __  __  ____    ____    ____    ____    _____   _____   ______
/\ \  /\ \/\  __`\/\ \/\ \/\  _`\ /\  _`\ /\  _`\ /\  _`\ /\  __`\/\  __`\/\__  _\
\ `\`\\/'/\ \ \/\ \ \ \ \ \ \,\L\_\ \ \L\_\ \ \L\ \ \ \L\ \ \ \/\ \ \ \/\ \/_/\ \/
/\ \ `\ /'  \ \ \ \ \ \ \ \ \/_\__ \\ \  _\L\ \ ,  /\ \ ,  /\ \ \ \ \ \ \ \ \ \ \ \
   `\ \ \   \ \ \_\ \ \ \_\ \/\ \L\ \ \ \L\ \ \ \\ \\ \ \\ \\ \ \_\ \ \ \_\ \ \ \ \
     \ \_\   \ \_____\ \_____\ `\____\ \____/\ \_\ \_\ \_\ \_\ \_____\ \_____\ \ \_\
      \/_/    \/_____/\/_____/\/_____/\/___/  \/_/\/ /\/_/\/ /\/_____/\/_____/  \/_/
```

**Versi:** 2.0.1  
**Author:** Masrul Hadi · Youserroot  
**Platform:** Windows 10 / 11 (64-bit)

> Menyiapkan Windows agar VMware dapat menggunakan nested virtualization sehingga mesin virtual Linux dapat menjalankan KVM. Setelah kebutuhan lab selesai, konfigurasi Windows dapat dikembalikan melalui Mode Normal.

---

## Daftar Isi

1. [Tentang proyek](#tentang-proyek)
2. [Prasyarat dan checklist](#prasyarat-dan-checklist)
3. [Quick start](#quick-start)
4. [Instalasi dan cara menjalankan](#instalasi-dan-cara-menjalankan)
5. [Menu dan parameter](#menu-dan-parameter)
6. [Backup dan log](#backup-dan-log)
7. [Verifikasi setelah restart](#verifikasi-setelah-restart)
8. [Konfigurasi VMware](#konfigurasi-vmware)
9. [Mengembalikan konfigurasi Windows](#mengembalikan-konfigurasi-windows)
10. [Troubleshooting](#troubleshooting)
11. [Emergency recovery](#emergency-recovery)
12. [FAQ](#faq)
13. [Peringatan keamanan](#peringatan-keamanan)
14. [Catatan kontributor](#catatan-kontributor)
15. [Lisensi dan kredit](#lisensi-dan-kredit)

---

## Tentang proyek

Windows menyediakan sejumlah fitur keamanan dan virtualisasi berbasis hypervisor, seperti **Hyper-V**, **Virtualization-Based Security (VBS)**, **Memory Integrity (HVCI)**, dan **Credential Guard**. Pada konfigurasi tertentu, fitur-fitur tersebut dapat berkonflik dengan kebutuhan VMware untuk menjalankan nested virtualization.

**VMware Lab Toolkit** adalah skrip PowerShell untuk membantu menyiapkan Windows dalam lingkungan lab dengan menonaktifkan komponen virtualisasi dan keamanan tertentu yang dapat menghalangi kebutuhan tersebut.

Toolkit menyediakan dua mode utama:

- **Mode Lab:** menyimpan konfigurasi awal, kemudian menonaktifkan komponen yang ditargetkan agar VMware dapat menggunakan virtualisasi hardware untuk nested virtualization.
- **Mode Normal:** mengembalikan konfigurasi berdasarkan backup sebelumnya atau melakukan reset ke konfigurasi default Windows.

Toolkit juga menyediakan pemeriksaan kesiapan sistem, pencatatan aktivitas, serta mekanisme pemulihan konfigurasi.

> **Penting:** Mode Lab mengurangi sebagian perlindungan keamanan Windows. Gunakan hanya pada perangkat yang memang disiapkan untuk kebutuhan lab, dan jalankan Mode Normal setelah selesai.

## Prasyarat dan checklist

Sebelum menjalankan **Mode Lab**, pastikan seluruh hal berikut sudah dipenuhi:

- [ ] **Backup BitLocker recovery key.** Simpan recovery key di lokasi yang dapat diakses jika Windows meminta verifikasi saat boot.
- [ ] **VMware Workstation sudah ditutup** dan seluruh virtual machine dalam keadaan *power off*.
- [ ] **Intel VT-x atau AMD-V aktif di BIOS/UEFI.** Skrip tidak dapat mengaktifkan fitur virtualisasi firmware.
- [ ] Menggunakan Windows **64-bit** (Home, Pro, Enterprise, atau Education).
- [ ] Memiliki hak **Administrator**. Skrip akan meminta elevasi UAC jika diperlukan.
- [ ] Perangkat bukan mesin produksi yang dikelola secara ketat melalui Intune atau Group Policy, kecuali perubahan telah dikoordinasikan dengan administrator IT.
- [ ] USB installer Windows tersedia sebagai media pemulihan (disarankan, terutama jika menggunakan opsi UEFI unlock).
- [ ] Menyediakan waktu sekitar **10–15 menit**, termasuk dua kali restart.

Untuk memeriksa atau mengekspor informasi BitLocker, jalankan PowerShell sebagai Administrator:

```powershell
manage-bde -protectors -get C:
```

Simpan recovery key dengan aman. Jangan membagikannya kepada orang lain.

## Quick start

Bagian ini ditujukan bagi pengguna yang sudah memahami dampak dan risiko perubahan konfigurasi Windows.

```powershell
# 1. Periksa kesiapan sistem (tidak mengubah konfigurasi)
.\modified-registry.ps1 -Action Check

# 2. Aktifkan Mode Lab
.\modified-registry.ps1 -Action Lab

# 3. Restart Windows, kemudian periksa kembali
.\modified-registry.ps1 -Action Check

# 4. Setelah kebutuhan lab selesai, pulihkan konfigurasi
.\modified-registry.ps1 -Action Normal
```

Restart diperlukan setelah Mode Lab dan setelah Mode Normal agar perubahan diterapkan.

> **Jangan melewati backup BitLocker recovery key.** Jika belum menyimpannya, jangan lanjutkan ke Mode Lab.

## Instalasi dan cara menjalankan

### 1. Siapkan skrip

Simpan skrip dengan nama:

```text
modified-registry.ps1
```

Pastikan file disimpan menggunakan encoding **UTF-8**. Contoh lokasi:

```text
C:\Tools\modified-registry.ps1
```

Jika menggunakan Notepad:

1. Pilih **File → Save As**.
2. Isi nama file `modified-registry.ps1`.
3. Pada **Save as type**, pilih `All Files (*.*)`.
4. Pilih encoding `UTF-8`.
5. Simpan file.

### 2. Jalankan melalui PowerShell

Buka PowerShell, kemudian pindah ke direktori tempat skrip disimpan:

```powershell
cd C:\Tools
powershell -ExecutionPolicy Bypass -File .\modified-registry.ps1
```

Jika muncul permintaan UAC, pilih **Yes**. Skrip akan melakukan relaunch dengan hak Administrator dan arsitektur PowerShell 64-bit secara otomatis.

### 3. Gunakan menu interaktif

Tekan **Enter** untuk membuka menu. Pilihan yang tersedia:

```text
[1] Cek kesiapan sistem
[2] MODE LAB    : menonaktifkan komponen virtualisasi dan keamanan
[3] MODE NORMAL : memulihkan konfigurasi Windows
[4] Keluar
```

Alur penggunaan yang disarankan:

```text
[1] Cek kesiapan
       |
       v
[2] Mode Lab
       |
       v
   Restart
       |
       v
[1] Verifikasi
       |
       v
 Gunakan VMware
       |
       v
[3] Mode Normal
       |
       v
   Restart
```

> **Alternatif:** File `.ps1` dapat dijalankan melalui klik kanan → **Run with PowerShell**. Namun, menjalankannya dari jendela PowerShell lebih disarankan agar pesan error tidak terlewat jika terjadi kegagalan.

### 4. Mode non-interaktif

Mode non-interaktif berguna untuk otomasi atau pengelolaan perangkat melalui Intune/SCCM. Parameter `-Yes` akan menjawab seluruh prompt konfirmasi dengan **Ya**. Karena itu, pastikan seluruh prasyarat dan backup telah dipenuhi sebelum menjalankannya.

```powershell
# Pemeriksaan saja
.\modified-registry.ps1 -Action Check

# Aktifkan Mode Lab tanpa prompt konfirmasi
.\modified-registry.ps1 -Action Lab -Yes -NoRestart

# Restart secara terpisah
shutdown /r /t 30

# Pulihkan konfigurasi berdasarkan backup
.\modified-registry.ps1 -Action Normal -RestoreMode Exact -Yes -NoRestart

# Atau reset ke default Windows
.\modified-registry.ps1 -Action Normal -RestoreMode Default -Yes -NoRestart

# Paksa membuat ulang backup jika kondisi sistem sudah berubah
.\modified-registry.ps1 -Action Lab -ForceReBackup
```

Gunakan `-NoRestart` hanya jika restart akan ditangani secara terpisah.

## Menu dan parameter

### Menu interaktif

| Menu | Fungsi |
|---|---|
| **[1] Cek kesiapan** | Memeriksa arsitektur sistem, status virtualisasi BIOS, hypervisor, VBS, HVCI, Credential Guard, fitur Windows terkait, BitLocker, Secure Boot, dan sisa entry UEFI unlock. |
| **[2] Mode Lab** | Membuat backup kondisi awal, kemudian menonaktifkan komponen yang ditargetkan, termasuk Hyper-V, Virtual Machine Platform, Hypervisor Platform, WSL, Windows Sandbox, Application Guard, VBS, HVCI, Credential Guard, dan System Guard. |
| **[3] Mode Normal** | Memulihkan konfigurasi berdasarkan backup sebelumnya atau melakukan reset ke default Windows. |
| **[4] Keluar** | Menutup menu dan mengakhiri skrip. |

### Parameter PowerShell

| Parameter | Nilai | Default | Keterangan |
|---|---|---|---|
| `-Action` | `Menu`, `Check`, `Lab`, `Normal` | `Menu` | Menentukan aksi yang dijalankan. |
| `-RestoreMode` | `Exact`, `Default` | `Exact` | Menentukan metode pemulihan ketika menggunakan `-Action Normal`. |
| `-NoRestart` | Switch | Nonaktif | Melewati permintaan restart di akhir proses. |
| `-Yes` | Switch | Nonaktif | Menyetujui seluruh prompt konfirmasi secara otomatis. |
| `-ForceReBackup` | Switch | Nonaktif | Memaksa pembuatan ulang backup. Backup lama akan diarsipkan terlebih dahulu. |

**Perbedaan metode pemulihan:**

- `Exact`: mengembalikan konfigurasi berdasarkan kondisi yang tersimpan dalam backup.
- `Default`: melakukan reset ke konfigurasi default Windows dan tidak menggunakan backup sebagai acuan pemulihan.

## Backup dan log

Toolkit menyimpan artefak backup dan log pada direktori berikut:

```text
C:\LabMode_Backup\
```

| File | Keterangan |
|---|---|
| `original_state.json` | Backup kondisi awal, termasuk registry, BCD, status fitur, firewall, dan metadata HVCI. **Jangan hapus selama Mode Lab aktif.** |
| `DeviceGuard_original.reg` | Ekspor registry key `DeviceGuard` (best-effort). |
| `bcd_original` | Ekspor konfigurasi BCD (best-effort). |
| `labmode.log` | Catatan aktivitas dan hasil setiap langkah. Log akan dirotasi secara otomatis jika ukurannya melebihi 1 MB. |
| `restored_<stamp>.json` | Arsip backup lama setelah proses Mode Normal. |

Jika terjadi kegagalan, periksa log dan cari entri dengan prefix `[FAIL]`:

```powershell
Get-Content C:\LabMode_Backup\labmode.log |
    Select-String '\[FAIL\]'
```

Jangan menghapus direktori backup sebelum proses pemulihan selesai dan hasilnya sudah diverifikasi.

## Verifikasi setelah restart

Setelah Mode Lab dijalankan dan Windows selesai restart, periksa status VBS, HVCI, dan Credential Guard.

Jalankan PowerShell:

```powershell
Get-CimInstance `
    -Namespace root\Microsoft\Windows\DeviceGuard `
    -ClassName Win32_DeviceGuard |
    Select-Object VirtualizationBasedSecurityStatus, SecurityServicesRunning
```

**Hasil yang diharapkan setelah Mode Lab:**

| Properti | Hasil yang diharapkan |
|---|---|
| `VirtualizationBasedSecurityStatus` | `0` (disabled) atau `1` (enabled, not running). |
| `SecurityServicesRunning` | Kosong (`()`) atau setidaknya tidak memuat `1` (Credential Guard) maupun `2` (HVCI). |

Kamu juga dapat menjalankan kembali skrip dan memilih menu **[1] Cek kesiapan sistem**. Periksa hasilnya dan pastikan tidak ada `[WARN]` atau `[ERR]` yang berkaitan dengan konfigurasi target.

## Konfigurasi VMware

Setelah status Windows diverifikasi, lakukan konfigurasi berikut di VMware Workstation:

1. Buka **VMware Workstation**.
2. Pilih virtual machine Linux yang akan digunakan (Ubuntu, Debian, Fedora, dan sebagainya).
3. Buka **VM Settings → Processors**.
4. Aktifkan opsi:
   - **Virtualize Intel VT-x/EPT or AMD-V/RVI**
   - **Virtualize CPU performance counters** (opsional)
5. Simpan pengaturan dan nyalakan virtual machine.

### Verifikasi KVM di Linux

Di dalam virtual machine Linux, jalankan:

```bash
# Periksa apakah flag virtualisasi CPU tersedia
egrep -c '(vmx|svm)' /proc/cpuinfo

# Periksa modul KVM
lsmod | grep kvm

# Instal utilitas pemeriksaan KVM (Debian/Ubuntu)
sudo apt install cpu-checker

# Periksa dukungan akselerasi KVM
sudo kvm-ok
```

Indikator yang diharapkan:

- Perintah `egrep` menghasilkan angka lebih dari `0`.
- Modul `kvm_intel` atau `kvm_amd` muncul pada hasil `lsmod`.
- `kvm-ok` menampilkan pesan `KVM acceleration can be used`.

Jika indikator tersebut terpenuhi, nested virtualization dan KVM siap digunakan sesuai konfigurasi virtual machine.

## Mengembalikan konfigurasi Windows

Setelah pekerjaan lab selesai, **jalankan Mode Normal** untuk memulihkan konfigurasi keamanan Windows.

### Pemulihan melalui menu

Pilih **[3] Mode Normal**. Menu pemulihan menyediakan pilihan:

```text
[1] Kembalikan PERSIS ke kondisi sebelum Mode Lab
[2] Reset ke default Windows
[3] Batal
```

Pilih opsi **[1] Kembalikan PERSIS** jika ingin menggunakan backup yang dibuat sebelum Mode Lab.

### Pemulihan melalui PowerShell

```powershell
.\modified-registry.ps1 -Action Normal -RestoreMode Exact -Yes -NoRestart
```

Setelah proses pemulihan selesai, restart Windows agar VBS, HVCI, Credential Guard, dan konfigurasi terkait dapat diterapkan kembali.

> Simpan backup sampai proses pemulihan dan verifikasi selesai. Jangan menghapus `C:\LabMode_Backup\` sebelum yakin konfigurasi sudah kembali seperti yang diharapkan.

## Troubleshooting

### VBS atau Credential Guard masih berjalan setelah restart

Salah satu kemungkinan penyebabnya adalah konfigurasi dikunci melalui UEFI.

Jalankan Mode Lab kembali. Jika skrip menawarkan opsi pembukaan kunci UEFI, pahami instruksinya sebelum menyetujui. Pada boot berikutnya, ikuti petunjuk yang muncul di layar.

### Ada langkah yang gagal

Periksa entri kegagalan pada log:

```powershell
Get-Content C:\LabMode_Backup\labmode.log |
    Select-String '\[FAIL\]'
```

Gunakan informasi tersebut untuk mengidentifikasi langkah yang gagal sebelum mencoba menjalankan ulang skrip.

### Skrip tidak dapat dijalankan: `running scripts is disabled`

Jalankan skrip dengan Execution Policy khusus untuk proses tersebut:

```powershell
powershell -ExecutionPolicy Bypass -File .\modified-registry.ps1
```

Alternatif lain, atur Execution Policy hanya untuk sesi PowerShell yang sedang digunakan:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

**Hindari** penggunaan `Set-ExecutionPolicy Unrestricted` secara global.

### File `.ps1` tidak dikenali atau hanya muncul di menu Open with

Windows Explorer mungkin menyembunyikan ekstensi file.

1. Buka File Explorer.
2. Pilih **View → Show → File name extensions**.
3. Periksa nama file.
4. Jika bernama `modified-registry.ps1.txt`, ubah menjadi `modified-registry.ps1`.

### File diblokir oleh Windows Defender atau SmartScreen

Jika file berasal dari sumber yang tepercaya dan kamu sudah memeriksa isinya, jalankan:

```powershell
Unblock-File .\modified-registry.ps1
```

Jangan membuka blokir file yang sumber atau isinya belum diverifikasi.

### Ingin melakukan pemulihan manual

File backup tersedia di:

```text
C:\LabMode_Backup\
```

Contoh perintah pemulihan manual:

```powershell
# Impor kembali registry DeviceGuard
reg import C:\LabMode_Backup\DeviceGuard_original.reg

# Impor konfigurasi BCD
bcdedit /import C:\LabMode_Backup\bcd_original
```

Pemulihan manual sebaiknya dilakukan hanya jika memahami dampak masing-masing perintah. Jika memungkinkan, gunakan Mode Normal agar mekanisme pemulihan toolkit dapat dijalankan secara terpusat.

## Emergency recovery

Bagian ini berisi langkah pemulihan untuk kondisi darurat. Gunakan hanya jika proses boot atau pemulihan normal mengalami masalah.

### BitLocker recovery prompt saat boot

Jika Windows meminta BitLocker recovery key, gunakan key yang sudah disimpan sebelumnya.

Recovery key dapat diperoleh dari:

- Akun Microsoft: <https://account.microsoft.com/devices/recoverykey>
- Hasil pencatatan perintah `manage-bde -protectors -get C:`.
- Salinan fisik atau media penyimpanan aman yang telah disiapkan sebelumnya.

### Boot berhenti pada layar SecConfig (UEFI unlock loop)

Jika layar SecConfig muncul saat boot, ikuti instruksi yang ditampilkan. Untuk mengaktifkan kembali VBS dan mengembalikan UEFI lock, pilih opsi yang sesuai pada layar tersebut (umumnya tombol **F3** atau **F10**, bergantung pada instruksi yang ditampilkan).

### Tidak dapat masuk Windows

Jika Windows tidak dapat diakses, boot menggunakan USB installer Windows, kemudian pilih:

**Repair your computer → Troubleshoot → Command Prompt**

Jalankan perintah berikut hanya jika memahami konteks pemulihan dan entry BCD yang dituju:

```cmd
bcdedit /delete {0cb3b571-2f2e-4343-a879-d86a476d7215} /f
bcdedit /deletevalue {bootmgr} bootsequence
bcdedit /set hypervisorlaunchtype auto
```

Setelah perintah selesai, restart komputer. Jika Windows berhasil dimuat, jalankan Mode Normal untuk melakukan pemulihan konfigurasi lebih lanjut.

### VMware masih tidak dapat menjalankan nested virtualization

Periksa kembali hal-hal berikut:

- Pastikan **Intel VT-x / AMD-V** aktif di BIOS/UEFI.
- Pastikan opsi **Virtualize Intel VT-x/EPT or AMD-V/RVI** aktif pada pengaturan prosesor virtual machine.
- Jalankan menu **[1] Cek kesiapan sistem** dan periksa peringatan terkait VBS, HVCI, atau Credential Guard.
- Periksa konfigurasi hypervisor Windows:

```powershell
bcdedit /enum {current}
```

Pada konfigurasi yang ditargetkan toolkit, nilai `hypervisorlaunchtype` diharapkan `Off`.

## FAQ

### Apakah skrip ini aman?

Skrip dirancang untuk membuat backup kondisi awal sebelum mengubah konfigurasi dan menyediakan mekanisme pemulihan. Namun, skrip mengubah pengaturan boot serta fitur keamanan Windows. Tidak ada jaminan bahwa setiap perangkat akan memiliki hasil yang sama.

Baca isi skrip, siapkan BitLocker recovery key, dan pahami risiko sebelum menjalankannya.

### Berapa kali komputer perlu restart?

Umumnya dua kali:

1. Setelah Mode Lab, agar perubahan konfigurasi diterapkan.
2. Setelah Mode Normal, agar konfigurasi keamanan yang dipulihkan diterapkan kembali.

### Bagaimana jika lupa menjalankan Mode Normal?

Windows tetap dapat berjalan, tetapi fitur seperti VBS, HVCI, dan Credential Guard dapat tetap nonaktif. Kondisi ini mengurangi perlindungan keamanan perangkat.

Jalankan Mode Normal setelah kebutuhan lab selesai.

### Apakah toolkit memengaruhi Windows Update?

Toolkit tidak ditujukan untuk menonaktifkan Windows Update. Namun, pembaruan Windows atau Windows Security dapat mengaktifkan kembali pengaturan seperti Memory Integrity.

Jalankan menu **[1] Cek kesiapan sistem** secara berkala untuk memeriksa status konfigurasi.

### Apakah bisa digunakan pada Windows Home?

Ya, dengan batasan. Sejumlah fitur seperti Application Guard, Windows Sandbox, atau komponen Hyper-V tertentu mungkin tidak tersedia pada edisi Home. Skrip dapat melaporkannya sebagai `[SKIP]`, bukan sebagai kegagalan.

### Bagaimana jika BitLocker aktif?

Skrip dapat memberikan peringatan dan meminta konfirmasi tambahan. Tetap simpan BitLocker recovery key sebelum menjalankan Mode Lab.

### Apakah aman digunakan pada komputer kantor?

Perangkat yang dikelola melalui Intune atau Group Policy dapat memiliki kebijakan yang mengembalikan konfigurasi setelah restart. Jangan menjalankan toolkit pada perangkat organisasi tanpa persetujuan administrator IT.

### Bagaimana cara berhenti menggunakan toolkit?

1. Jalankan **Mode Normal**.
2. Pilih opsi **Kembalikan PERSIS** jika ingin memulihkan kondisi sebelum Mode Lab.
3. Restart Windows.
4. Verifikasi konfigurasi.
5. Setelah yakin proses pemulihan selesai, folder `C:\LabMode_Backup\` dapat dihapus jika sudah tidak diperlukan.

## Peringatan keamanan

- **Mode Lab menurunkan sebagian perlindungan keamanan Windows**, termasuk VBS, Memory Integrity, dan Credential Guard. Gunakan hanya selama diperlukan.
- Selama Mode Lab, fitur yang bergantung pada Hyper-V atau WSL2 dapat terdampak, termasuk **WSL2, Docker Desktop dengan backend WSL2/Hyper-V, Windows Sandbox**, dan emulator berbasis Hyper-V.
- Windows Update atau Windows Security dapat mengaktifkan kembali Memory Integrity. Periksa statusnya melalui menu **[1]**.
- Jangan menghapus file backup selama Mode Lab masih aktif atau sebelum pemulihan diverifikasi.
- Pada perangkat yang dikelola organisasi, koordinasikan perubahan dengan administrator IT.
- Skrip disediakan **apa adanya**, tanpa jaminan. Pengguna bertanggung jawab memahami dan menerima risiko sebelum menjalankannya.

## Catatan kontributor

- Skrip PowerShell (`.ps1`) harus menggunakan encoding **UTF-8**.
- Target kompatibilitas pengujian adalah **Windows PowerShell 5.1+**; hindari penggunaan fitur yang hanya tersedia di PowerShell 7.
- Perlakukan perubahan pada BCD, registry, dan nama fitur DISM sebagai perubahan yang berpotensi memengaruhi kompatibilitas pemulihan dari versi sebelumnya.
- Untuk perubahan besar, lakukan pengujian *round-trip*:

```text
Mode Lab
   ↓
Restart
   ↓
Verifikasi
   ↓
Mode Normal
   ↓
Restart
   ↓
Verifikasi pemulihan
```

- Untuk konsistensi file pada Windows, `.gitattributes` disarankan menetapkan line ending CRLF untuk file PowerShell:

```gitattributes
*.ps1 text eol=crlf
```

## Lisensi dan kredit

**VMware Lab Toolkit v2.0.1**  
Dibuat oleh **Masrul Hadi · Youserroot**.

Terima kasih kepada semua pihak yang telah menguji dan memberikan masukan pada versi `.bat` (v1.1.0). Versi **v2.0.1** merupakan penulisan ulang penuh menggunakan PowerShell, dengan backup JSON, deteksi BitLocker lintas edisi, dan pemulihan firewall per profil.
