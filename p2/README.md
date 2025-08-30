# Part 2: K3s and Three Simple Applications

Bu bölümde tek bir sanal makine üzerinde K3s server modu çalıştırarak 3 farklı web uygulaması deploy ediyoruz ve bunlara host-based routing ile erişim sağlıyoruz.

## 🎯 Amaç

- K3s server modu kurulumu
- 3 web uygulaması deployment'ı
- Host-based routing ile traefik ingress kullanımı
- Replica set yönetimi (app2 için 3 replica)
- ConfigMap ile HTML content yönetimi

## 📁 Proje Yapısı

```
p2/
├── Vagrantfile                 # Tek makine (sciftciS) konfigürasyonu
├── scripts/
│   ├── server.sh              # K3s server kurulum scripti
│   └── create-configmaps.sh   # HTML dosyalarından ConfigMap oluşturma
├── confs/
│   ├── src/
│   │   ├── app1.html         # App1 için HTML içeriği
│   │   ├── app2.html         # App2 için HTML içeriği
│   │   └── app3.html         # App3 için HTML içeriği
│   ├── app1.yaml             # App1 Deployment + Service
│   ├── app2.yaml             # App2 Deployment + Service (3 replica)
│   ├── app3.yaml             # App3 Deployment + Service
│   └── ingress.yaml          # Traefik Ingress konfigürasyonu
└── README.md                 # Bu dosya
```

## 🚀 Kurulum ve Çalıştırma

### 1. Sanal Makineyi Başlat
```bash
cd p2
vagrant up
```

### 2. SSH ile Bağlan
```bash
vagrant ssh sciftciS
```

### 3. Durumu Kontrol Et
```bash
# Node durumu
kubectl get nodes

# Pod'ları kontrol et
kubectl get pods

# Service'leri kontrol et
kubectl get svc

# Ingress durumu
kubectl get ingress
```

## 🌐 Uygulamalara Erişim

Makinenin IP'si: **192.168.56.110**

### Host Dosyası Düzenlemesi
Yerel makinenizde `/etc/hosts` dosyasına ekleyin:
```
192.168.56.110  app1.com
192.168.56.110  app2.com
```

### Erişim URL'leri
- **App1**: http://app1.com → app1 uygulamasına yönlendirilir (1 replica)
- **App2**: http://app2.com → app2 uygulamasına yönlendirilir (3 replica)
- **App3**: http://192.168.56.110 → varsayılan uygulama (1 replica)

## 📊 Uygulama Detayları

| Uygulama | Host | Replica Sayısı | Açıklama |
|----------|------|----------------|----------|
| App1 | app1.com | 1 | Gri tema, temel nginx |
| App2 | app2.com | 3 | Mavi tema, 3 replica ile load balance |
| App3 | default | 1 | Sarı tema, varsayılan uygulama |

## 🔧 Teknik Detaylar

### Vagrant Konfigürasyonu
- **OS**: Alpine Linux 3.18
- **RAM**: 1024 MB
- **CPU**: 1 core
- **Network**: Private network (192.168.56.110)

### Kubernetes Resources Açıklaması

#### 1. ConfigMap Stratejisi
```bash
# create-configmaps.sh içeriği
kubectl create configmap app-one-config --from-file=index.html=/vagrant/confs/src/app1.html
```
- HTML dosyaları src/ klasöründe ayrı tutulur
- kubectl ile ConfigMap'ler dinamik oluşturulur
- Her ConfigMap'te "index.html" anahtarı ile content saklanır

#### 2. Deployment Yapısı
```yaml
# app1.yaml örneği
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
spec:
  replicas: 1  # app2'de 3 replica
  selector:
    matchLabels:
      app: app1
  template:
    spec:
      containers:
      - name: app1
        image: nginx:alpine  # Aynı image, farklı content
        volumeMounts:
        - name: app1-config
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html  # ConfigMap'teki anahtar
      volumes:
      - name: app1-config
        configMap:
          name: app-one-config
```

#### 3. Service Konfigürasyonu
```yaml
apiVersion: v1
kind: Service
metadata:
  name: app1
spec:
  selector:
    app: app1  # Pod'ları label ile seç
  ports:
  - port: 80
    targetPort: 80  # Container port
```

#### 4. Ingress Routing
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    kubernetes.io/ingress.class: "traefik"
spec:
  rules:
  - host: app1.com        # Host-based routing
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1    # Service'e yönlendir
            port:
              number: 80
  - http:                 # Default route (host yok)
      paths:
      - path: /
        backend:
          service:
            name: app3    # app3 default
```

### K3s Özellikler
- Server modu (single-node cluster)
- Traefik ingress controller (built-in)
- Lightweight Kubernetes distribution

## 🐛 Sorun Giderme

### Pod'lar çalışmıyor
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Ingress çalışmıyor
```bash
kubectl describe ingress app-ingress
kubectl get svc -n kube-system  # traefik service kontrolü
```

### ConfigMap kontrol
```bash
kubectl get configmap
kubectl describe configmap app-one-config
```

## 📝 Test Senaryoları

### 1. Replica Test
```bash
# App2'nin 3 replica'sını kontrol et
kubectl get pods -l app=app-two

# Pod'lardan birini sil ve tekrar oluşup oluşmadığını kontrol et
kubectl delete pod <app-two-pod-name>
kubectl get pods -l app=app-two
```

### 2. Ingress Test
```bash
# Farklı host header'ları ile test
curl -H "Host: app1.com" http://192.168.56.110
curl -H "Host: app2.com" http://192.168.56.110
curl http://192.168.56.110  # default app3
```

### 3. Load Balancing Test
```bash
# App2'nin 3 replica'sı arasında load balance kontrolü
for i in {1..10}; do curl -H "Host: app2.com" http://192.168.56.110; done

# Pod IP'lerini görmek için
kubectl get pods -l app=app2 -o wide
```

## 📚 Öğrenilen Konular

### Kubernetes Core Concepts
- **Deployment**: Pod'ların declarative yönetimi
- **ReplicaSet**: Desired state ile pod sayısı kontrolü
- **Service**: Pod'lara network erişim (ClusterIP)
- **ConfigMap**: Configuration data yönetimi
- **Volume Mount**: ConfigMap'i container'a mount etme

### Ingress ve Networking
- **Ingress Controller**: L7 load balancing
- **Host-based Routing**: HTTP Host header'ına göre yönlendirme
- **PathType Prefix**: URL path matching
- **Default Backend**: Fallback routing

### K3s Specifics
- **Lightweight Kubernetes**: Production-ready, minimal resource
- **Built-in Traefik**: Otomatik ingress controller
- **Single-node Setup**: Development/testing için ideal

### DevOps Practices
- **Infrastructure as Code**: Vagrant + YAML manifests
- **Immutable Infrastructure**: ConfigMap ile content separation
- **Declarative Configuration**: kubectl apply pattern

## 🎓 Değerlendirme Kriterleri

- [x] Tek sanal makine ile K3s server kurulumu
- [x] 3 farklı web uygulaması deployment'ı
- [x] Host-based routing (app1.com, app2.com, default)
- [x] App2 için 3 replica konfigürasyonu
- [x] Nginx:alpine image kullanımı (tek image, farklı content)
- [x] ConfigMap ile HTML content yönetimi
- [x] Modüler YAML yapısı (ayrı dosyalar)
- [x] Proper Kubernetes resource definitions

## 🗣️ Sunum Hazırlığı

### Anlatman Gereken Teknik Konular:

1. **"ConfigMap nasıl çalışıyor?"**
   - HTML dosyaları src/'de ayrı
   - kubectl create configmap komutu
   - volumeMount ile container'a aktarım

2. **"Neden tek image, farklı content?"**
   - nginx:alpine base image
   - ConfigMap ile runtime'da content injection
   - Image rebuild gerektirmez

3. **"Ingress routing nasıl çalışıyor?"**
   - Host header kontrolü
   - app1.com → app1 service
   - app2.com → app2 service  
   - Default → app3 service

4. **"App2'de neden 3 replica?"**
   - High availability
   - Load distribution
   - Kubernetes ReplicaSet controller

5. **"Single-node K3s vs Multi-node?"**
   - Development/testing için yeterli
   - Resource efficiency
   - Production'da multi-node tercih edilir