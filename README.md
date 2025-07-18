# FastAPI Scheduled Runner Setup Guide

This guide will help you set up a FastAPI application that runs every 2 hours using systemd, with proper error handling and notifications.

## Prerequisites

- Linux system with systemd
- Python 3.8+
- sudo access
- Email configuration (optional, for notifications)

## Step 1: Prepare Your FastAPI Project

1. **Create project directory:**
   ```bash
   sudo mkdir -p /opt/fastapiscript
   cd /opt/fastapiscript
   ```

2. **Create virtual environment:**
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

3. **Install dependencies:**
   ```bash
   pip install fastapi uvicorn[standard]
   
   # Create requirements.txt
   cat > requirements.txt << EOF
   fastapi==0.104.1
   uvicorn[standard]==0.24.0
   pydantic==2.5.0
   EOF
   ```

4. **Create your FastAPI application:**
   - Copy the sample `main.py` from the artifacts above
   - Modify the `simulate_work()` function with your actual automation logic

5. **Set proper permissions:**
   ```bash
   sudo chown -R your-username:your-group /opt/fastapiscript
   chmod +x /opt/fastapiscript/main.py
   ```

## Step 2: Install the Runner Script

1. **Copy the runner script:**
   ```bash
   sudo cp fastapiscript.sh /usr/local/bin/
   sudo chmod +x /usr/local/bin/fastapiscript.sh
   ```

2. **Edit the configuration in the script:**
   ```bash
   sudo nano /usr/local/bin/fastapiscript.sh
   ```
   
   Update these variables:
   ```bash
   FASTAPI_DIR="/opt/fastapiscript"
   PYTHON_VENV="/opt/fastapiscript/venv"
   FASTAPI_MODULE="main:app"
   ```

## Step 3: Install the Notification Script

1. **Copy the notification script:**
   ```bash
   sudo cp fastapi-failure-notification.sh /usr/local/bin/
   sudo chmod +x /usr/local/bin/fastapi-failure-notification.sh
   ```

2. **Configure notifications:**
   ```bash
   sudo nano /usr/local/bin/fastapi-failure-notification.sh
   ```
   
   Update:
   - Email recipient: Change `sam@brainzcode.com`
   - Slack webhook URL: Replace `YOUR_SLACK_WEBHOOK_URL`

## Step 4: Install Systemd Files

1. **Create the service file:**
   ```bash
   sudo nano /etc/systemd/system/fastapiscript.service
   ```
   Copy the service configuration from the artifacts above.

2. **Create the timer file:**
   ```bash
   sudo nano /etc/systemd/system/fastapiscript.timer
   ```
   Copy the timer configuration from the artifacts above.

3. **Create the failure notification service:**
   ```bash
   sudo nano /etc/systemd/system/fastapi-failure-notification@.service
   ```
   Copy the notification service configuration from the artifacts above.

4. **Update user/group in service files:**
   Replace `your-username` and `your-group` with your actual user and group.

## Step 5: Create Log Directory

```bash
sudo mkdir -p /var/log/fastapiscript
sudo chown your-username:your-group /var/log/fastapiscript
sudo chmod 755 /var/log/fastapiscript
```

## Step 6: Install Email Support (Optional)

For email notifications:

```bash
# Ubuntu/Debian
sudo apt-get install mailutils

# CentOS/RHEL
sudo yum install mailx

# Configure postfix or your preferred MTA
sudo dpkg-reconfigure postfix
```

## Step 7: Enable and Start Services

1. **Reload systemd:**
   ```bash
   sudo systemctl daemon-reload
   ```

2. **Enable and start the timer:**
   ```bash
   sudo systemctl enable fastapiscript.timer
   sudo systemctl start fastapiscript.timer
   ```

3. **Check timer status:**
   ```bash
   sudo systemctl status fastapiscript.timer
   sudo systemctl list-timers fastapiscript.timer
   ```

## Step 8: Testing

1. **Test the runner script manually:**
   ```bash
   sudo -u your-username /usr/local/bin/fastapiscript.sh
   ```

2. **Test the service:**
   ```bash
   sudo systemctl start fastapiscript.service
   sudo systemctl status fastapiscript.service
   ```

3. **Test failure notification:**
   ```bash
   sudo systemctl start fastapi-failure-notification@fastapiscript.service
   ```

4. **View logs:**
   ```bash
   # Service logs
   sudo journalctl -u fastapiscript.service -f
   
   # Timer logs
   sudo journalctl -u fastapiscript.timer -f
   
   # Application logs
   tail -f /var/log/fastapiscript/fastapi-$(date +%Y%m%d).log
   ```

## Step 9: Monitoring and Maintenance

### Check Next Run Time
```bash
systemctl list-timers fastapiscript.timer
```

### View Recent Runs
```bash
journalctl -u fastapiscript.service --since="24 hours ago"
```

### Check Failure Count
```bash
cat /tmp/fastapi-failure-count
```

### Manual Run
```bash
sudo systemctl start fastapiscript.service
```

### Stop/Disable
```bash
# Stop timer (prevents new runs)
sudo systemctl stop fastapiscript.timer

# Disable timer (prevents auto-start on boot)
sudo systemctl disable fastapiscript.timer

# Stop running service
sudo systemctl stop fastapiscript.service
```

## Customization Options

### Change Schedule
Edit `/etc/systemd/system/fastapiscript.timer`:
```ini
# Every hour
OnCalendar=hourly

# Every 4 hours
OnCalendar=*:0/4:00

# Daily at 2 AM
OnCalendar=*-*-* 02:00:00

# Weekdays at 9 AM and 5 PM
OnCalendar=Mon..Fri 09,17:00:00
```

### Timeout Configuration
Edit the service file to change the 2-hour timeout:
```bash
# In fastapiscript.sh
TIMEOUT=3600  # 1 hour instead of 2
```

### Add More Notification Methods
Extend `fastapi-failure-notification.sh` with:
- Discord webhooks
- Telegram bots
- PagerDuty integration
- SMS notifications

### Health Check Endpoint
Your FastAPI app includes a `/health` endpoint. You can monitor it externally:
```bash
# While the service is running
curl http://localhost:8000/health
```

## Troubleshooting

### Common Issues

1. **Permission Denied:**
   - Check file permissions and ownership
   - Ensure user has access to log directories

2. **Virtual Environment Not Found:**
   - Verify the path in `PYTHON_VENV` variable
   - Ensure virtual environment is created and activated

3. **Service Fails to Start:**
   - Check `journalctl -u fastapiscript.service`
   - Verify Python dependencies are installed
   - Check FastAPI application syntax

4. **Timer Not Running:**
   - Ensure timer is enabled: `systemctl is-enabled fastapiscript.timer`
   - Check timer logs: `journalctl -u fastapiscript.timer`

5. **Notifications Not Working:**
   - Test email configuration: `echo "test" | mail -s "test" sam@brainzcode.com`
   - Check Slack webhook URL
   - Verify notification script permissions

### Log Locations
- Service logs: `journalctl -u fastapiscript.service`
- Application logs: `/var/log/fastapiscript/fastapi-YYYYMMDD.log`
- Notification logs: `/var/log/fastapiscript/notifications.log`

This setup provides a robust, monitored FASTAPISCRIPT runner that executes every 2 hours with proper error handling and notifications.