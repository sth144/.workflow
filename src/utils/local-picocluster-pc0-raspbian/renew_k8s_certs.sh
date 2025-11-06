#!/bin/bash
set -e

LOGFILE="/home/picocluster/.cache/.workflow/cronjob.log"
echo "=== Cert renewal run: $(date) ===" >> "$LOGFILE"

# Renew all kubeadm-managed certs
/usr/bin/kubeadm certs renew all >> "$LOGFILE" 2>&1

# Restart control-plane components (so they load new certs)
systemctl restart kubelet >> "$LOGFILE" 2>&1

# Optional: verify apiserver is back up
sleep 10
kubectl get nodes >> "$LOGFILE" 2>&1 || echo "kubectl check failed" >> "$LOGFILE"

echo "=== Renewal complete ===" >> "$LOGFILE"
