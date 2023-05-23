


### Краткое описание и необходиме действия которые нужно выполнить 
* определиться с выбором сервиса (cloud, VPS, etc.) "*в нашем случае неттоп*"
* установить/поднять ОС "*в нашем случае Ubuntu*" 
* для повышения безопасности создать пользователя (не root, user, user1, etc.) с надёжным паролем если речь идёт об Вашем личном VPS.
* выполняем подключение по ssh с помощью ssh-copy-id username@servername после отключаем в файле sshd аутентификацию по паролю для повышения безопасности
* зарегистрировать или же получить доменное имя (в админ панели создать А запись(указав Ваш белый ip) и CNAME запись, в дальнейшем нам это понадобится
* заказать(услуга платная) у Вашего провайдера публичный внешний ip адрес ("белый") "*есть ещё вариант с DynDNS но его мы рассматривать не будем*"
* пробросить порты на Вашем роутере для доступа к серверу из внем "*мы будем использовать 80 и 443, а так же 22 для ssh *"
* установить и сконфигурировать nginx 
* получить сертификаты для https соединения "*мы будем использовать Certbot от Let`sEncrypt*"
* создать docker-compose.yml для установки nextcloud в docker контейнере для удобства использования и последующего обновления

# Установка и настройка nginx proxy 
### Обновим пакеты
```bash
sudo apt update
```
### Выполним установку nginx
```bash
sudo apt install nginx
```
### Проверим статус приложения 
```bash
sudo systemctl status nginx
```
### Для того что бы nginx стартовал при запуске системы / или он не активен
```bash
sudo systemctl enable nginx.service
```
### Выполним переход в папку и создадим Ваш nginx proxy файл
```bash
cd /etc/nginx/sites-available
```
```bash
sudo nano nginx_name_file # обычно название совпадает с доменным именем или сайтом для избежания путаницы
```
### Добавляем следующие содержимое
```bash
upstream your_file_name { # "*указываем ip адреc и порт на котором запущен наш контейнер "
  server 0.0.0.0:8083;
  }  # так же можно указать ip Вашего сервера для проверки работоспособности 
  # без поднятого контейнера но в таком случае необходимо закомментировать строки отмеченые "for_test" ,
  # а так же весь блок с 443 портом


server { # "*блок перенаправления запросов с http на https*"
  listen 80;
  server_name nextcloud.your_domain.com; 
  return 301 https://nextcloud.your_domain.com$request_uri;      # "for_test"
}

server {  # "*блок https соединения с использованием SSl-сертификата*"
  listen 443 ssl;
  server_name nextcloud.your_domain.com;
    ssl_certificate /etc/letsencrypt/live/nextcloud.your_domain.com/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/nextcloud.your_domain.com/privkey.pem; # managed by Certbot
  include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

   # "* эти параметры нам нужны для определения размера загружаемых файлов
   # (уменьшаем или увеличиваем с учётом разрядности файловой системы)*"
  client_max_body_size 1024m; 
  client_body_buffer_size 128k;

  location / { # "*этот блок отвечает за проксирование и обработку запросов*"
    proxy_set_header HOST $host;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Host $server_name;

    proxy_pass http://your_file_name;
    # "*подключение буфера и таймаута для Вашего сервера*"
    proxy_buffering on;
    proxy_buffer_size 16k;
    proxy_buffers 4 16k;
    proxy_busy_buffers_size 16k;
    proxy_read_timeout 300s;  
  }
}
```
### Для активации nginx создадим символьную ссылку 
```bash
sudo ln -s /etc/nginx/sites-available/your_nginx_file_name /etc/nginx/sites-enabled/
```

### Что бы изменения вступили в силу выполняем 
```bash
sudo systemctl restart nginx.service # для жёсткой перезагрузки
```
```bash
sudo systemctl reload nginx.service # для мягкой перезагрузки (предпочтительнее если необходимо выполнить перезагрузку плавно постепенно перезапуская службы)

```

### Для проверки правильности синтаксиса или наличиия ошибок 
```bash
sudo nginx -t
```

### Установим сертификат с помощью Certbot # https://certbot.eff.org/
```bash
sudo apt install certbot python3-certbot-nginx
```
### Запустим стандартную команду и следуя инструкциям выполним получение сертификата
"*Важно! Certbot работает только с существующими доменными(хоть и существует возможность получить тестовый сертификат он работает по такому же принципу) именами ввиду того что он проверяет их наличие в DNS(если Вы зарегистрировали доменное имя и верно настроили его, а бот даёт ошибку, значит нужно подождать информация могла ещё не обновится , так же можно выполнить команду **ping** или **nslookup** для проверки работоспособности домена)*"
```bash
sudo certbot --nginx
```
### Установка Docker https://docs.docker.com/engine/install/  
### docker compose  https://github.com/docker/compose/releases
# Далее займемся установкой и настройкой nextcloud
```bash
sudo mkdir -p /app/nextcloud
cd /app/nextcloud
```
```bash
sudo nano docker-compose.yml
```

```bash
version: "2.1"

services:
  nextcloud:
    container_name: nextcloud
    image: "nextcloud:25.0-apache"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Kiev
      - REDIS_HOST=redis-nextcloud
      - REDIS_HOST_PASSWORD=your_redis_password
      - PHP_MEMORY_LIMIT=3G
      - PHP_UPLOAD_LIMIT=1024M
      - PHP_POST_MAX_SIZE=1024M
      - PHP_MAX_INPUT_TIME=7200
      - PHP_MAX_EXECUTION_TIME=7200
    volumes:
      - nextcloud_apps:/var/www/html/apps
      - nextcloud_custom_apps:/var/www/html/custom_apps
      - nextcloud_config:/var/www/html/config
      - nextcloud_data:/var/www/html/data
    ports:
      - 8083:80
    restart: unless-stopped
    depends_on:
      - postgres-nextcloud
      - redis-nextcloud
    networks:
      - default

  postgres-nextcloud:
    image: postgres:14.1-alpine
    container_name: postgres-nextcloud
    restart: unless-stopped
    environment:
      - POSTGRES_DB=nextcloud
      - POSTGRES_USER=nextcloud
      - POSTGRES_PASSWORD=your_pgsql_password
    volumes:
      - database:/var/lib/postgresql/data
    networks:
      - default

  redis-nextcloud:
    image: redis:alpine
    container_name: redis-nextcloud
    command: redis-server --requirepass your_redis_password
    restart: unless-stopped
    networks:
      - default

networks:
  default:
    name: docnet

volumes:
  nextcloud_apps:
  nextcloud_custom_apps:
  nextcloud_config:
  nextcloud_data:
  database:
```
### В конфиге  обращаем внимание на строки PUID и PGID и указываем от которого хотим запускать контейнер 
### Конфигурируем PostgreSQL
```bash
- POSTGRES_DB=nextcloud
- POSTGRES_USER=nextcloud
- POSTGRES_PASSWORD=your_pgsql_password
```

### Для увеличения размера загружаемых файлов, использования оперативной памяти и тайм аута используем переменные окружения *environment*
```bash
      - PHP_MEMORY_LIMIT=3G
      - PHP_UPLOAD_LIMIT=1024M
      - PHP_POST_MAX_SIZE=1024M
      - PHP_MAX_INPUT_TIME=7200
      - PHP_MAX_EXECUTION_TIME=7200
```

# Подключаем Redis
```bash
- REDIS_HOST=redis-nextcloud
- REDIS_HOST_PASSWORD=your_redis_password
```
```bash
redis-nextcloud:
  image: redis:alpine
  container_name: redis-nextcloud
  command: redis-server --requirepass your_redis_password
  restart: unless-stopped
```
### После выполнения всех конфигураций запускаем контейнер и продолжаем настройку Redis
```bash
sudo docker-compose up -d
```
### Для проверки работы Redis
```bash
sudo apt install redis-tools
```
### Отобразим список всех контейнеров 
```bash
sudo docker ps
```
### Открываем содержимое с учётом id или имени redis
```bash
sudo docker inspect redis-nextcloud
```
находим интерисующий нас IPAddress и выполняем команду
```bash
redis-cli -a your_redis_password -h IPAddress ping
```
Если всё ок то в ответ мы получим PONG

после выполняем 
```bash
redis-cli -a your_redis_password -h IPAddress monitor

```
Ответ должен быть OK

Переключимся на браузер с Nextcloud и обновим там страницу. В результате чего в логе мы увидим как побежали данные


# Ввиду того что некоторые плагины требуют принудительный https включаем его, а так же в этом файле указываем trusted_domains (если не указано)
```bash
sudo docker compose stop
```
```bash
sudo docker exec -it --user root <your_container_id_or_name> bash
```
```bash
apt-get update
apt install nano
```
```bash
nano config/config.php
```
```bash
<?php
$CONFIG = array (
  'overwriteprotocol' => 'https',
  'htaccess.RewriteBase' => '/',
  'memcache.local' => '\\OC\\Memcache\\APCu',
  'apps_paths' => 
```
```bash
trusted_domains' =>  # редактируем в том случае если Ваш домен отсутствует
  array (
    0 => 'your_domain.com',
    1 => 'www.your_domain.com',
    2 => 'nextcloud.your_domain.com',
  ),
```


# За дополнительной информацией можете посетить 
https://docs.nextcloud.com
https://hub.docker.com/_/nextcloud
