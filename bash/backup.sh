BACKUP_DIR="/opt/k3s-backup"
TIMESTAMP=$(date +%F_%H-%M-%S)
SOURCE_DB="/var/lib/rancher/k3s/server/db/state.db"
BACKUP_FILE="$BACKUP_DIR/state.db.$TIMESTAMP"
mkdir -p "$BACKUP_DIR"
cp "$SOURCE_DB" "$BACKUP_FILE"

ls -1tr "$BACKUP_DIR"/state.db.* | head -n -50 | xargs -d '\n' rm -f --

CRON_JOB="*/1 * * * * /root/k3s-backup.sh"

crontab -l 2>/dev/null | grep -q "$CRON_JOB"

if [ $? -ne 0 ]; then
  (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
  echo ".Cronjob added to run every 1 minutes."
else
  echo "Cronjob already exists. Nothing to change."
fi

