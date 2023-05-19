# nginx-proxy-nextcloud-docker-postgresql-redis


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
* создать Dockerfile и docker-compose.yml для установки nextcloud в docker контейнере для удобства использования и последующего обновления

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

### Для проверки правильности синтаксиса или наличии ошибок 
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
### Для проверки работоспособности необходимо в поисковой строке указать ip Вашего сервера или же доменное имя

sudo docker network create -d bridge evilcorp
sudo docker network connect evilcorp portainer
