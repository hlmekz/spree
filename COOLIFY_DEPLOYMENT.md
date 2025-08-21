# Spree Commerce Coolify Deployment Rehberi

## Ön Hazırlık

### 1. GitHub Repository'yi Hazırla
- Projeyi GitHub'a push edin
- Repository'nin public veya Coolify'ın erişebileceği şekilde ayarlandığından emin olun

### 2. Coolify'da Yeni Uygulama Oluştur

1. Coolify dashboard'una giriş yapın
2. **"+ New"** butonuna tıklayın
3. **"Application"** seçin
4. **"Public Repository"** veya **"Private Repository"** seçin

### 3. Repository Bilgilerini Girin

```
Repository URL: https://github.com/your-username/your-spree-repo
Branch: main (veya deploy etmek istediğiniz branch)
Build Pack: Dockerfile
```

## Environment Variables Ayarları

Coolify'da uygulamanızın **Environment** sekmesine gidin ve şu değişkenleri ekleyin:

### Zorunlu Değişkenler:
```bash
# Database (Coolify'dan alınan)
DATABASE_URL=postgres://postgres:FwYlRW4Hej2YdPJFutcnbxsNcZCFxa0Ky95bqZIZoy1XStFdANV8GnYHlicFaCsQ@ug448cskokw4cg0800wco4cg:5432/postgres

# Redis (Coolify'dan alınan)
REDIS_URL=redis://default:7T65pZg3qjhMuhzX3bdqWYLmXgQ8zvZtJ7KtkPTPklbV71M97U4HO6nMeBzb6yWd@e48ggc8gco84s8woc8g0c0so:6379/0

# Rails
RAILS_ENV=production
RACK_ENV=production
SECRET_KEY_BASE=8297c8d1eaabbe71aa55f61460ade4c67806e67a61ee89517c85d49e7363a344fe2c937e2fb1a1194523b37051fd5e33e5edb16b7bb69647f1067e1cdba744ed

# Spree
SPREE_ADMIN_EMAIL=admin@example.com
SPREE_ADMIN_PASSWORD=secure_password
```

### Opsiyonel Değişkenler:
```bash
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
SPREE_FRONTEND_AUTO_CAPTURE=true
SPREE_ALLOW_SSL_IN_PRODUCTION=true
SEED_DATABASE=true  # İlk deploy için
PRECOMPILE_ASSETS=true  # Gerekirse
```

## Database ve Redis Kurulumu

### PostgreSQL Database Oluştur:
1. Coolify'da **"+ New"** → **"Database"** → **"PostgreSQL"**
2. Database adı: `spree-postgres`
3. Username: `spree_user`
4. Password: güçlü bir şifre
5. Database name: `spree_production`

### Redis Oluştur:
1. Coolify'da **"+ New"** → **"Database"** → **"Redis"**
2. Service adı: `spree-redis`

### Database URL'lerini Güncelle:
Database ve Redis oluşturduktan sonra, Coolify size internal URL'ler verecek:
```bash
DATABASE_URL=postgresql://spree_user:password@spree-postgres:5432/spree_production
REDIS_URL=redis://spree-redis:6379/0
```

## Deploy Ayarları

### Build Command (Opsiyonel):
```bash
# Coolify otomatik olarak Dockerfile'ı kullanacak
```

### Start Command:
```bash
./bin/start-production
```

### Port Ayarı:
```
Port: 3000
```

### Health Check:
```
Health Check Path: /health (eğer health endpoint'iniz varsa)
```

## Deploy İşlemi

1. Tüm ayarları yaptıktan sonra **"Deploy"** butonuna tıklayın
2. Build loglarını takip edin
3. İlk deploy'da database migration'lar çalışacak

## Deploy Sonrası Kontroller

### 1. Logları Kontrol Edin:
- Coolify'da **"Logs"** sekmesinden uygulama loglarını kontrol edin
- Database bağlantısının başarılı olduğundan emin olun

### 2. Database Migration:
```bash
# Eğer migration'lar çalışmadıysa manuel olarak çalıştırın
bundle exec rails db:migrate
```

### 3. Admin Kullanıcı Oluştur:
```bash
# Rails console'dan admin kullanıcı oluşturun
bundle exec rails console
# Console'da:
Spree::User.create!(email: 'admin@example.com', password: 'password123', admin: true)
```

## Domain Ayarları

1. Coolify'da **"Domains"** sekmesine gidin
2. Custom domain ekleyin veya Coolify'ın verdiği subdomain'i kullanın
3. SSL sertifikası otomatik olarak oluşturulacak

## Troubleshooting

### Build Hatası:
- Dockerfile'ın doğru olduğundan emin olun
- Dependencies'lerin eksik olmadığını kontrol edin

### Database Bağlantı Hatası:
- DATABASE_URL'in doğru olduğundan emin olun
- PostgreSQL servisinin çalıştığını kontrol edin

### Asset Precompile Hatası:
- `PRECOMPILE_ASSETS=true` environment variable'ını ekleyin
- Dockerfile'da asset precompile adımının olduğundan emin olun

## Güvenlik Notları

1. **SECRET_KEY_BASE**: Güçlü, rastgele bir key kullanın (`rails secret` komutuyla oluşturabilirsiniz)
2. **Database Şifreleri**: Güçlü şifreler kullanın
3. **Environment Variables**: Hassas bilgileri Coolify'ın environment variables özelliğinde saklayın
4. **SSL**: Production'da mutlaka SSL kullanın

## Otomatik Deploy

GitHub'a her push'ta otomatik deploy için:
1. Coolify'da **"Git"** sekmesine gidin
2. **"Auto Deploy"** özelliğini aktif edin
3. İstediğiniz branch'i seçin