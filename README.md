

### Brief Description and Necessary Actions to Perform
* Choose a service (cloud, VPS, etc.) "in our case, a mini-PC"
* Install/bring up the OS "in our case, Ubuntu"
* For enhanced security, create a user (not root, user, user1, etc.) with a strong password if it's your personal VPS.
* Connect via SSH using ssh-copy-id username@servername and disable password authentication in the SSH configuration file for improved security.
* Register or obtain a domain name (create an A record in the admin panel, specifying your public IP) as we will need it later.
* Order (paid service) a public external IP address ("white IP") from your provider. "Alternatively, DynDNS is an option, but we won't consider it here."
* Set up port forwarding on your router to access the server externally. "We will use ports 80 and 443, as well as 22 for SSH."
* Install and configure Nginx.
* Obtain HTTPS certificates. "We will use Certbot from Let's Encrypt."
* Create a docker-compose.yml file to install Nextcloud in a Docker container for convenience and future updates.

# Installation and Configuration of Nginx Proxy
### Update packages
```bash
sudo apt update
```
### Install Nginx

```bash
sudo apt install nginx
```
### Check the status of the application

```bash
sudo systemctl status nginx
```
### Set Nginx to start on system boot, if not already active

```bash
sudo systemctl enable nginx.service
```
### Navigate to the directory and create your Nginx proxy file

```bash
cd /etc/nginx/sites-available
```
```bash
sudo nano nginx_name_file # Usually, the name corresponds to the domain name or site to avoid confusion
```
### ДAdd the following content

```bash
upstream your_file_name { # "*Specify the IP address and port on which our container is running*"
  server 0.0.0.0:8083;
  }  # You can also specify the IP of your server for testing purposes without a running container, but in # that case, you need to comment out the lines marked "for_test"
  # as well as the entire block with port 443


server { # "*Block for redirecting HTTP requests to HTTPS*"
  listen 80;
  server_name nextcloud.your_domain.com; 
  return 301 https://nextcloud.your_domain.com$request_uri;      # "for_test"
}

server {  # "*HTTPS connection block using SSL certificate*"
  listen 443 ssl;
  server_name nextcloud.your_domain.com;
    ssl_certificate /etc/letsencrypt/live/nextcloud.your_domain.com/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/nextcloud.your_domain.com/privkey.pem; # managed by Certbot
  include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

   # "*These parameters are necessary for determining the size of uploaded files
   # (increase or decrease depending on the file system's capacity)*"
  client_max_body_size 1024m; 
  client_body_buffer_size 128k;

  location / { # "*This block handles proxying and request processing*"
    proxy_set_header HOST $host;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Host $server_name;

    proxy_pass http://your_file_name;
    # "*connecting buffer and timeout for your server*"
    proxy_buffering on;
    proxy_buffer_size 16k;
    proxy_buffers 4 16k;
    proxy_busy_buffers_size 16k;
    proxy_read_timeout 300s;  
  }
}
```
### To activate Nginx, create a symbolic link


```bash
sudo ln -s /etc/nginx/sites-available/your_nginx_file_name /etc/nginx/sites-enabled/
```

### To apply the changes, restart Nginx


```bash
sudo systemctl restart nginx.service # for hard reboot

```
```bash
sudo systemctl reload nginx.service # for a soft reboot (preferred if you want to perform a graceful reboot gradually restarting services)

```

### You can check the syntax and test for any configuration errors
```bash
sudo nginx -t
```

### Installing and Configuring Certbot # https://certbot.eff.org/
```bash
sudo apt install certbot python3-certbot-nginx
```
### Run the standard command and follow the instructions to get the certificate
"*Important! Certbot only works with existing domain names (although it is possible to get a test certificate, it works on the same principle) names because it checks their presence in the DNS (if you registered a domain name and configured it correctly, and the bot gives an error , then you need to wait, the information might not be updated yet, you can also run the **ping** or **nslookup** command to check the health of the domain)*"
```bash
sudo certbot --nginx
```
### Install Docke https://docs.docker.com/engine/install/  
### Install Docker Compose  https://github.com/docker/compose/releases
### Next, let's install and configure nextcloud
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
### Adjust the PUID and PGID values to the user ID and group ID of the user you want to run the container as
### Configure the PostgreSQL settings
```bash
- POSTGRES_DB=nextcloud
- POSTGRES_USER=nextcloud
- POSTGRES_PASSWORD=your_pgsql_password
```

### To increase the size of uploaded files, use of RAM and timeout, use the environment variables *environment*
```bash
      - PHP_MEMORY_LIMIT=3G
      - PHP_UPLOAD_LIMIT=1024M
      - PHP_POST_MAX_SIZE=1024M
      - PHP_MAX_INPUT_TIME=7200
      - PHP_MAX_EXECUTION_TIME=7200
```

# Connecting Redis
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
### After completing all the configurations, we start the container and continue configuring Redis
```bash
sudo docker-compose up -d
```
### To check if Redis is working
```bash
sudo apt install redis-tools
```
### Display a list of all containers

```bash
sudo docker ps
```
### Open content based on id or redis name
```bash
sudo docker inspect redis-nextcloud
```
find the IPAddress that interests us and execute the command
```bash
redis-cli -a your_redis_password -h IPAddress ping
```
If everything is ok, then in response we will get PONG

after we execute 
```bash
redis-cli -a your_redis_password -h IPAddress monitor

```
Answer should be OK

Let's switch to the browser with Nextcloud and refresh the page there. As a result, in the log we will see how the data ran


# Due to the fact that some plugins require forced https, enable it, and also specify trusted_domains in this file (if not specified)
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
trusted_domains' =>  # edit if your domain is missing
  array (
    0 => 'your_domain.com',
    1 => 'www.your_domain.com',
    2 => 'nextcloud.your_domain.com',
  ),
```


# For more information you can visit 
https://docs.nextcloud.com
https://hub.docker.com/_/nextcloud
