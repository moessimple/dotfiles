call_dataurl() {
    call_dotfiles_function dataurl "$@"
}

given_fake_mime_type_detection() {
    write_fake_binary file "case \"\$3\" in
    *binary*) printf 'application/octet-stream\n' ;;
    *)        printf 'text/plain\n' ;;
esac"
}

given_fake_clipboard() {
    write_fake_binary pbcopy "cat > '$fixture/clipboard'"
}

assert_clipboard_content() {
    assert_file_content "$fixture/clipboard" "$1"
}
