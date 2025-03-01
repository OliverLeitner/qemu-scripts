#!/bin/sh
clear
echo ""
echo "======================= running virtual machines ======================="
echo ""
ps a | awk '/qemu/ {print $9}' | cut -d "," -f 1
echo "========================================================================"
echo ""
exit 0
