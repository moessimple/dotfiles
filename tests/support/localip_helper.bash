call_localip() { call_dotfiles_alias localip; }

given_fake_ifconfig_with_mixed_addresses() {
    write_fake_binary ifconfig "cat <<'OUT'
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
	inet 127.0.0.1 netmask 0xff000000
	inet6 ::1 prefixlen 128
en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
	ether aa:bb:cc:dd:ee:ff
	inet6 fe80::1234:5678:9abc:def0%en0 prefixlen 64 secured scopeid 0x6
	inet 192.168.1.42 netmask 0xffffff00 broadcast 192.168.1.255
OUT"
}
