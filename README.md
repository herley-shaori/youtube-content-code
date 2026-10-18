# Kode Pendamping Tutorial YouTube

Repositori ini berisi kode pendamping tutorial YouTube **Herley Shaori**: kode aplikasi,
script, konfigurasi Terraform, dan contoh teknis lainnya. Setelah menonton video,
Anda dapat membuka folder tutorial terkait untuk mempelajari dan mencoba kodenya.

## Daftar tutorial

| Tutorial | Teknologi | Kode dan panduan | Video |
| --- | --- | --- | --- |
| OAuth 2.0 implicit flow dengan Cognito dan API Gateway | AWS, Terraform, Python | [Buka tutorial](oauth2-implicit-cognito-aws-apigw/) | Tautan belum dicantumkan |

Tautan video akan ditambahkan setelah URL video terkait tersedia. Setiap folder
memiliki README sendiri yang menjelaskan prasyarat, konfigurasi, cara menjalankan,
dan cara membersihkan resource jika diperlukan.

## Mulai dari sini

```sh
git clone https://github.com/herley-shaori/youtube-content-code.git
cd youtube-content-code
```

1. Pilih tutorial dari tabel di atas atau tautan pada deskripsi video.
2. Baca README di folder tutorial tersebut.
3. Siapkan dependensi dan konfigurasi yang disebutkan di sana.
4. Jalankan perintah dari dalam folder tutorial, bukan dari root repositori.

Tutorial berdiri sendiri. Anda tidak perlu memasang dependensi seluruh repositori
atau menjalankan seluruh contoh sekaligus.

## Struktur repositori

```text
.
├── README.md
├── templates/
│   └── tutorial/
│       └── README.md                 # template dokumentasi tutorial baru
└── oauth2-implicit-cognito-aws-apigw/  # satu folder untuk satu tutorial
    ├── README.md
    ├── *.tf                          # konfigurasi infrastruktur
    └── lambda_function.py            # kode aplikasi contoh
```

Tutorial baru menggunakan folder dengan nama deskriptif dalam format `kebab-case`,
misalnya `python-rest-api` atau `terraform-aws-vpc`. Kode sederhana dapat ditempatkan
langsung dalam folder tutorial. Jika tutorial menggabungkan banyak komponen,
gunakan subfolder seperti `app/`, `terraform/`, atau `scripts/` sesuai kebutuhan.
Terraform bukan syarat: susunan file mengikuti teknologi yang dibahas.

## Menambahkan tutorial

1. Buat folder baru di root dengan nama topik tutorial.
2. Salin [template README](templates/tutorial/README.md) ke folder tersebut dan
   lengkapi semua bagian yang relevan; hapus bagian yang tidak diperlukan.
3. Tambahkan kode, versi dependensi, dan contoh konfigurasi tanpa kredensial.
4. Cantumkan URL video yang sebenarnya pada README tutorial dan tabel di atas.
   Jika belum tersedia, tulis bahwa tautannya belum dicantumkan.
5. Jelaskan hasil yang diharapkan, keterbatasan contoh, dan cara membersihkan
   resource yang dibuat.
6. Cantumkan tautan langsung ke folder tutorial pada deskripsi YouTube agar
   penonton tidak perlu mencari kode dari halaman utama.

Untuk versi kode yang perlu tetap cocok dengan video tertentu, tautkan ke commit
atau tag yang sesuai saat video dipublikasikan.

## Konfigurasi dan resource

- Gunakan kredensial milik Anda melalui mekanisme autentikasi teknologi terkait.
  Jangan menyimpan token, password, file `.env`, atau Terraform state di Git.
- Simpan contoh konfigurasi sebagai `.env.example` atau `terraform.tfvars.example`
  dengan nilai placeholder dan penjelasan variabel.
- Contoh cloud dapat membuat resource berbayar. Baca konfigurasi dan hasil plan
  sebelum deployment; ikuti panduan pembersihan setelah selesai.
- Setiap contoh merupakan bahan pembelajaran. README tutorial menjelaskan batasan
  yang perlu dipertimbangkan sebelum mengadaptasinya untuk penggunaan lain.
