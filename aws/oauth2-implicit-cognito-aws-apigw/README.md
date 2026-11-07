# OAuth 2.0 Implicit Flow dengan Cognito dan API Gateway

Contoh kode pendamping tutorial integrasi Amazon Cognito, API Gateway REST API,
dan AWS Lambda menggunakan Terraform. Lambda menggunakan Python 3.12 dan
mengembalikan respons `Hello, World!`.

## Video

Tautan video belum dicantumkan.

## Prasyarat

- Terraform CLI dan akses untuk mengunduh provider AWS, Random, Local, serta Null.
  Contoh lama ini belum menetapkan versi Terraform dan provider yang digunakan.
- AWS CLI dengan kredensial akun latihan yang dapat mengelola resource contoh.
- Utilitas `zip`, yang dipanggil oleh konfigurasi Terraform untuk mengemas Lambda.
- Region AWS `ap-southeast-3` (Jakarta), sesuai `providers.tf`.

## Isi folder

| File | Fungsi |
| --- | --- |
| `providers.tf` | Konfigurasi provider dan region AWS. |
| `variables.tf` | Nama proyek yang dipakai untuk penamaan resource. |
| `cognito.tf` | User pool, app client implicit flow, domain, dan pembuatan pengguna demo. |
| `apigw.tf` | REST API, Cognito authorizer, integrasi Lambda, dan stage `dev`. |
| `lambda.tf` | IAM role dan pengemasan serta deployment fungsi Lambda. |
| `lambda_function.py` | Handler Python untuk respons contoh. |
| `locals.tf` | Tag pada fungsi Lambda. |

## Konfigurasi

Baca file Terraform sebelum deployment. Nama proyek default adalah
`oauth2-implicit-apigateway-authorizer`. Nama ini juga digunakan untuk domain
Cognito sehingga mungkin perlu diganti dengan nama yang tersedia.

Kode yang ada memakai pengguna demo `herley@mailinator.com` di `cognito.tf` dan
callback/logout URL Postman di konfigurasi app client. Ganti dengan nilai milik
Anda sebelum mencoba. Jangan memakai contoh ini untuk kredensial pribadi atau
pengguna produksi.

Anda dapat mengatur nama proyek melalui file lokal `terraform.tfvars`:

```hcl
project_name = "nama-proyek-unik-anda"
```

File tersebut dan Terraform state diabaikan oleh Git. Gunakan profil AWS CLI atau
mekanisme kredensial AWS lokal yang sesuai; jangan menulis access key di kode.

## Validasi dan deployment

Jalankan dari folder tutorial ini:

```sh
cd aws/oauth2-implicit-cognito-aws-apigw
terraform init
terraform validate
terraform plan
```

Tinjau hasil plan dan potensi biaya resource AWS. Jika konfigurasi sudah sesuai,
jalankan deployment secara terpisah:

```sh
terraform apply
```

Deployment juga menjalankan AWS CLI untuk membuat pengguna Cognito demo dan
utilitas `zip` untuk mengemas Lambda. Perintah di atas adalah panduan untuk
penonton; resource AWS tidak otomatis dibuat dengan meng-clone repositori.

## Hasil yang diharapkan

Konfigurasi mendefinisikan endpoint `POST /serve` pada stage `dev`. Setelah
menyelesaikan alur masuk Cognito dan memperoleh ID token yang valid untuk user
pool terkait, kirim token melalui header `Authorization` saat memanggil endpoint
API Gateway. Handler Lambda menghasilkan status `200` dengan body `Hello, World!`.

URL API dan detail app client dapat dilihat melalui konsol AWS; contoh ini belum
menyediakan output Terraform untuk keduanya.

## Pembersihan

Dari folder tutorial yang sama dan menggunakan state serta akun AWS yang sama:

```sh
terraform plan -destroy
terraform destroy
```

Tinjau resource yang akan dihapus sebelum menyetujui. Periksa pengguna demo yang
dibuat melalui AWS CLI jika deployment sempat gagal atau tidak selesai.

## Catatan dan keterbatasan

- Ini adalah contoh lama dengan implicit flow, bukan implementasi aplikasi login
  lengkap. Antarmuka login dan contoh HTTP client belum disertakan.
- Password sementara pengguna demo dibuat secara acak dan disimpan dalam state;
  output ditandai sensitif. Proses mengganti password awal belum diotomatisasi.
- Pembuatan pengguna melalui `local-exec` belum memiliki penanganan pengguna yang
  sudah ada. Periksa kondisi akun jika mengulang deployment yang gagal.
- IAM role Lambda belum memasang kebijakan penulisan log CloudWatch.
- Versi provider belum dipatok dan deployment contoh ini belum diverifikasi ulang.
  Periksa kompatibilitas provider sebelum mengikuti demo.
