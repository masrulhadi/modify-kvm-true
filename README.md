# VMware Lab Toolkit

> Siapkan Windows agar **VMware** bisa menjalankan **nested virtualization / KVM**, dan kembalikan lagi kapan saja.

**Author:** youserroot | simas  
**Versi:** 1.0.0  
**Platform:** Windows 10 / 11 (Pro, Enterprise, Education, Home dengan batasan fitur)

---

## Kenapa script ini ada?

Windows modern memakai hypervisor sendiri (Hyper-V, VBS, Memory Integrity, dll) yang "mengambil alih" Intel VT-x / AMD-V. Akibatnya VMware tidak bisa memakai virtualisasi hardware secara penuh, dan nested virtualization (KVM di dalam VM) gagal atau sangat lambat.

Toolkit ini mematikan semua komponen tersebut dengan aman, **menyimpan kondisi asli**, dan bisa mengembalikannya persis seperti semula.

## Fitur

| Menu | Fungsi |
|------|--------|
| **[1] Cek kesiapan** | Memeriksa arsitektur, virtualisasi BIOS, hypervisor, VBS, HVCI, Credential Guard, dan fitur Windows terkait |
| **[2] Mode Lab** | Mematikan Hyper-V, Virtual Machine Platform, Hypervisor Platform, WSL, Windows Sandbox, Application Guard, VBS, HVCI, Credential Guard, System Guard |
| **[3] Mode Normal** | Mengembalikan persis ke kondisi sebelum Mode Lab, atau mengaktifkan fitur default Windows |

Keunggulan:

- Backup kondisi asli otomatis (registry, `bcdedit`, status fitur) di `C:\LabMode_Backup`
- Mengenali kode sukses DISM `3010` dan melewati fitur yang tidak ada di edisi Windows Anda
- Pengecekan status tidak bergantung bahasa Windows
- Opsi pembukaan kunci UEFI untuk VBS / Credential Guard yang terkunci
- Log lengkap di `C:\LabMode_Backup\labmode.log`

## Cara pakai

1. Unduh `VMware_Lab_Toolkit.bat`.
2. Klik kanan, **Run as administrator** (script juga meminta izin otomatis).
3. Pilih **[1]** untuk melihat kondisi awal.
4. Pilih **[2]** lalu restart.
5. Pilih **[1]** lagi untuk memverifikasi. Targetnya semua `OK`.
6. Di VMware, buka pengaturan VM, lalu **Processors**, dan centang **Virtualize Intel VT-x/EPT or AMD-V/RVI**.
7. Setelah selesai, jalankan **[3]** untuk mengembalikan keamanan Windows.

## Prasyarat

- Intel VT-x atau AMD-V aktif di BIOS/UEFI
- Windows 64-bit
- Hak administrator

## Peringatan

Mode Lab **menurunkan perlindungan keamanan Windows** (VBS, Memory Integrity, Credential Guard). Gunakan hanya saat dibutuhkan dan kembalikan dengan Mode Normal setelah selesai.

Selama Mode Lab, fitur berikut tidak berfungsi: WSL2, Docker Desktop (backend WSL2/Hyper-V), Windows Sandbox, dan emulator berbasis Hyper-V.

Windows Update atau Windows Security dapat mengaktifkan Memory Integrity lagi. Jalankan menu **[1]** untuk memeriksa.

Script ini diberikan apa adanya, tanpa jaminan apa pun. Gunakan dengan risiko sendiri dan baca isi script sebelum menjalankannya.

## Pemecahan masalah

- **VBS atau Credential Guard masih berjalan setelah restart:** kemungkinan dikunci UEFI. Jalankan Mode Lab lagi dan jawab `Y` pada opsi pembukaan kunci UEFI, lalu ikuti prompt di layar saat boot.
- **Ada langkah yang gagal:** buka `C:\LabMode_Backup\labmode.log`.
- **Ingin kembali manual:** file `DeviceGuard_original.reg` dan `bcd_original` ada di folder backup.

## Catatan untuk kontributor

File `.bat` harus memakai line ending **CRLF**. Repo ini menyertakan `.gitattributes` untuk memastikannya.

---

Dibuat oleh **youserroot | simas**
