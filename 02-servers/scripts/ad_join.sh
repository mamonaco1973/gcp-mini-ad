#!/bin/bash
set -euo pipefail

LOG=/root/boot.log
mkdir -p /root
touch "$LOG"
chmod 600 "$LOG"
exec > >(tee -a "$LOG" | logger -t startup-script -s 2>/dev/console) 2>&1
trap 'echo "ERROR at line $LINENO"; exit 1' ERR

echo "startup-script start: $(date -Is)"

RUN_ONCE_MARKER="/var/lib/startup-script.ad-join.done"
if [[ -f "$RUN_ONCE_MARKER" ]]; then
  echo "NOTE: Run-once marker exists ($RUN_ONCE_MARKER). Exiting."
  exit 0
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y \
  less unzip jq \
  realmd sssd-ad sssd-tools libnss-sss libpam-sss \
  adcli samba-common-bin samba-libs oddjob oddjob-mkhomedir \
  packagekit krb5-user nano vim

secret_json="$(gcloud secrets versions access latest --secret="admin-ad-credentials-mini")"
admin_password="$(echo "$secret_json" | jq -r '.password')"
admin_username="$(echo "$secret_json" | jq -r '.username' | sed 's/.*\\//')"

echo "NOTE: Joining domain: ${domain_fqdn}"
echo -e "$admin_password" | /usr/sbin/realm join -U "$admin_username" \
  "${domain_fqdn}" --verbose 

SSHD_CFG="/etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
if [[ -f "$SSHD_CFG" ]]; then
  sed -i 's/^[[:space:]]*PasswordAuthentication[[:space:]]\+no/PasswordAuthentication yes/g' "$SSHD_CFG"
  sed -i 's/^[[:space:]]*#\{0,1\}PasswordAuthentication[[:space:]]\+no/PasswordAuthentication yes/g' "$SSHD_CFG"
else
  echo "NOTE: SSHD config drop-in not found: $SSHD_CFG (skipping)"
fi

SSSD_CFG="/etc/sssd/sssd.conf"
if [[ -f "$SSSD_CFG" ]]; then
  sed -i 's/use_fully_qualified_names[[:space:]]*=[[:space:]]*True/use_fully_qualified_names = False/g' "$SSSD_CFG"
  sed -i 's/ldap_id_mapping[[:space:]]*=[[:space:]]*True/ldap_id_mapping = False/g' "$SSSD_CFG"
  sed -i 's/access_provider[[:space:]]*=[[:space:]]*ad/access_provider = simple/g' "$SSSD_CFG"
  sed -i 's|fallback_homedir[[:space:]]*=[[:space:]]*/home/%u@%d|fallback_homedir = /home/%u|g' "$SSSD_CFG"
else
  echo "ERROR: Missing SSSD config: $SSSD_CFG"
  exit 1
fi

touch /etc/skel/.Xauthority
chmod 600 /etc/skel/.Xauthority

pam-auth-update --enable mkhomedir || true
systemctl restart sssd
systemctl restart ssh || systemctl restart sshd || true

echo "%linux-admins ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/10-linux-admins >/dev/null
chmod 440 /etc/sudoers.d/10-linux-admins

mkdir -p "$(dirname "$RUN_ONCE_MARKER")"
touch "$RUN_ONCE_MARKER"
echo "startup-script complete: $(date -Is)"