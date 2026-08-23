call_cud() { call_dotfiles_alias cud; }
call_cup() { call_dotfiles_alias cup; }

# The composer alias itself resolves to "herd composer", and alias expansion
# is recursive, so cud/cup end up invoking "herd composer ..." rather than
# "composer ..." directly. The fake binary has to be named herd, not composer.
given_fake_composer_dependencies() {
    write_fake_binary herd "if [ \"\$1\" = composer ] && [ \"\$2\" = show ] && [ \"\$3\" = -s ]; then
cat <<'SHOW'
name     : vendor/app

requires
php ^8.2
vendor/direct-prod ^1.0

requires (dev)
vendor/direct-dev ^2.0
SHOW
fi"
}

assert_herd_called_with() {
    assert_binary_called_with herd "$1"
}
