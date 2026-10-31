# Raithu-Connect AWS deployment (3 EC2 servers)

Assumptions: Ubuntu 22.04/24.04, Git installed, one VPC. Replace all placeholders. Keep DB on a private IP.

## Security groups
- Frontend SG: inbound TCP 22 from your IP; TCP 80 from internet; TCP 443 from internet when TLS is configured.
- Backend SG: inbound TCP 22 from your IP (or bastion); TCP 4000 ONLY from Frontend SG. Do not expose 4000 publicly.
- Database SG: inbound TCP 22 from your IP (or bastion); TCP 5432 ONLY from Backend SG. Do not expose 5432 publicly.
- Backend and DB must be able to reach each other on the VPC private network. Prefer private subnets for DB.

## Source of truth
Push this repository to your own private/public GitHub repository. On each EC2 server, clone into /tmp, then copy only the required component into its permanent location. Never store .env secrets in GitHub.

## Frontend server
```bash
sudo apt update && sudo apt install -y nginx git curl
cd /tmp
git clone https://github.com/YOUR_GITHUB_USER/raithu-connect.git
sudo mkdir -p /var/www/raithu-connect
cd /tmp/raithu-connect/frontend
cp .env.example .env
nano .env  # leave VITE_API_URL and VITE_SOCKET_URL empty; Nginx proxies /api and /socket.io
npm install
npm run build
sudo cp -a dist/. /var/www/raithu-connect/
sudo cp /tmp/raithu-connect/deployment/frontend-nginx.conf /etc/nginx/sites-available/raithu-connect
sudo nano /etc/nginx/sites-available/raithu-connect  # replace BACKEND_PRIVATE_IP with Server 2 private IP
sudo ln -sf /etc/nginx/sites-available/raithu-connect /etc/nginx/sites-enabled/raithu-connect
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl enable --now nginx && sudo systemctl reload nginx
```
Install Node.js LTS and npm before `npm install` if they are not present. Vite embeds VITE_* values at build time, so rebuild after changing them.

## Backend server
```bash
sudo apt update && sudo apt install -y git curl
# Install a supported Node.js LTS release and npm (use the official Node.js installation instructions).
sudo adduser --system --group --home /opt/raithu-connect raithu
cd /tmp
git clone https://github.com/YOUR_GITHUB_USER/raithu-connect.git
sudo mkdir -p /opt/raithu-connect
sudo cp -a /tmp/raithu-connect/backend/. /opt/raithu-connect/
sudo chown -R raithu:raithu /opt/raithu-connect
sudo -u raithu npm --prefix /opt/raithu-connect install --omit=dev
sudo -u raithu cp /opt/raithu-connect/.env.example /opt/raithu-connect/.env
sudo nano /opt/raithu-connect/.env
# Set DATABASE_URL with DB private IP, strong JWT_SECRET, and FRONTEND_ORIGIN=http://FRONTEND_PUBLIC_IP
sudo chmod 600 /opt/raithu-connect/.env
sudo cp /tmp/raithu-connect/deployment/backend.service /etc/systemd/system/raithu-connect.service
sudo systemctl daemon-reload
sudo systemctl enable --now raithu-connect
sudo systemctl status raithu-connect
curl http://127.0.0.1:4000/health
```
If Node is installed somewhere other than /usr/bin/node, update ExecStart in the service file.

## Database server
```bash
sudo apt update && sudo apt install -y postgresql postgresql-contrib git
sudo systemctl enable --now postgresql
cd /tmp
git clone https://github.com/YOUR_GITHUB_USER/raithu-connect.git
sudo -u postgres psql
```
Inside psql, replace password with a long random password:
```sql
CREATE USER raithu_app WITH PASSWORD 'REPLACE_WITH_STRONG_PASSWORD';
CREATE DATABASE raithu_connect OWNER raithu_app;
\\q
```
Copy schema and apply:
```bash
sudo mkdir -p /opt/raithu-connect/database
sudo cp /tmp/raithu-connect/database/schema.sql /opt/raithu-connect/database/
sudo -u postgres psql -d raithu_connect -f /opt/raithu-connect/database/schema.sql
```
Configure PostgreSQL to listen on the DB server's private IP and add a restrictive `pg_hba.conf` rule allowing only BACKEND_PRIVATE_IP/32 for `raithu_connect` and `raithu_app`. Restart PostgreSQL. Exact config file locations vary by PostgreSQL version; inspect with `sudo -u postgres psql -c 'SHOW config_file'` and `SHOW hba_file`.

## Test
- Frontend: open `http://FRONTEND_PUBLIC_IP`
- Backend health: `curl http://FRONTEND_PUBLIC_IP/health` (Nginx proxies this to the backend).
- Expected health JSON: `{"status":"ok","database":"connected"}`
- Register one farmer, publish a product, register a consumer, then request an order.
- Open browser developer tools -> Network/Console if frontend API calls fail.

## Important MVP limitations
- Demo chat room is shared by all signed-in users; do not use it for private customer conversations until order/conversation authorization is implemented.
- Order endpoint creates a request but does not yet provide farmer accept/reject, inventory deduction, payments, notifications, image uploads, or delivery tracking.
- Add HTTPS, private per-order chat authorization, rate limiting, validation, backups, audit logging, and production security review before real users or real orders.
