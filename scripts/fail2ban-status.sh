#!/bin/bash
# Quick Fail2Ban status — useful for demo/screenshot
echo "=== Fail2Ban Status ==="
fail2ban-client status

echo ""
echo "=== SSH Jail ==="
fail2ban-client status sshd

echo ""
echo "=== Recent banned IPs ==="
grep "Ban" /var/log/fail2ban.log | tail -20
