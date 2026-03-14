# Frappe CRM on Railway

Deploy [Frappe CRM](https://github.com/frappe/crm) on [Railway](https://railway.app) using a single Docker container with Supervisor.

## Architecture

```
Railway Project
├── Frappe CRM Service (this repo)
│   ├── Gunicorn (backend API)
│   ├── Nginx (reverse proxy, port 80)
│   ├── Socket.IO (realtime)
│   ├── Worker Short Queue
│   ├── Worker Long Queue
│   └── Scheduler
├── MariaDB 10.8
└── Redis (Alpine)
```

## Deploy to Railway

### Step 1: Fork/Push this repo to GitHub

Push this repository to your GitHub account.

### Step 2: Create Railway Project

1. Go to [railway.app](https://railway.app) and create a new project
2. Add the following services:

#### 2a. Add MariaDB
- Click **"+ New"** → **"Database"** → **"MySQL"** (Railway uses MariaDB)
- Or add a Docker-based MariaDB service with image `mariadb:10.8`
- Set environment variables:
  ```
  MYSQL_ROOT_PASSWORD=<strong_password>
  ```
- Note the connection details (host, port, password)

#### 2b. Add Redis
- Click **"+ New"** → **"Database"** → **"Redis"**
- Note the connection URL

#### 2c. Add Frappe CRM Service
- Click **"+ New"** → **"GitHub Repo"** → Select this repository
- Attach a **volume** at: `/home/frappe/frappe-bench/sites`
- Set **environment variables**:

```env
# Database
DB_HOST=<mariadb_hostname>
DB_PORT=3306
DB_ROOT_PASSWORD=<mariadb_root_password>

# Redis (use internal Railway URLs)
REDIS_CACHE=redis://<redis_host>:6379
REDIS_QUEUE=redis://<redis_host>:6379

# Site
SITE_NAME=crm.localhost
ADMIN_PASSWORD=<your_secure_admin_password>
```

### Step 3: Initial Site Setup

After the first deployment completes:

1. Open the Railway **shell** for the Frappe CRM service
2. Run the setup script:
   ```bash
   bash /home/frappe/railway-setup.sh
   ```
3. Wait for the script to complete (~3-5 minutes)

### Step 4: Configure and Redeploy

1. In Railway settings for the Frappe CRM service:
   - **Remove** any start command override (use Dockerfile's ENTRYPOINT)
   - Set **HTTP port** to `80`
2. **Redeploy** the service

### Step 5: Access CRM

- Navigate to the Railway-provided URL
- Login with:
  - Username: `Administrator`
  - Password: `<ADMIN_PASSWORD you set>`
- Access CRM at: `<your-url>/crm`

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `DB_HOST` | ✅ | - | MariaDB hostname |
| `DB_PORT` | ❌ | `3306` | MariaDB port |
| `DB_ROOT_PASSWORD` | ✅ | - | MariaDB root password |
| `REDIS_CACHE` | ✅ | - | Redis URL for cache |
| `REDIS_QUEUE` | ✅ | - | Redis URL for queue |
| `SITE_NAME` | ❌ | `crm.localhost` | Frappe site name |
| `ADMIN_PASSWORD` | ✅ | `admin` | Administrator password |

## Custom Domain (Optional)

1. In Railway settings → **Networking** → **Custom Domain**
2. Add your domain and configure DNS as instructed
3. Update `SITE_NAME` to match your custom domain

## Backup

### Database
```bash
# Via Railway shell
cd /home/frappe/frappe-bench
su frappe -c "bench --site crm.localhost backup --with-files"
```

Backups are stored in `/home/frappe/frappe-bench/sites/crm.localhost/private/backups/`

## Estimated Cost

- **Railway Hobby**: ~$5/month base + usage
- **Expected total**: $10-30/month depending on traffic

## Troubleshooting

### Site not loading
- Check that all 3 services are running (CRM, MariaDB, Redis)
- Verify environment variables are correctly set
- Check Railway logs for errors

### Database connection error
- Ensure `DB_HOST` matches the MariaDB internal hostname
- Verify `DB_ROOT_PASSWORD` is correct

### Assets not loading
- Run `su frappe -c "bench build"` in the Railway shell
- Redeploy the service
