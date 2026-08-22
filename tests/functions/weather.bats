#!/usr/bin/env bats

load ../support/test_helper
load ../support/weather_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary curl
}

teardown() {
    teardown_dotfiles_fixture
}

@test "weather defaults to Castrop-Rauxel when no city is given" {
    # Act
    run call_weather

    # Assert
    assert_success
    assert_binary_called_with curl "http://wttr.in/Castrop-Rauxel?F"
}

@test "weather looks up a given city, replacing spaces with plus signs" {
    # Act
    run call_weather "New York"

    # Assert
    assert_success
    assert_binary_called_with curl "http://wttr.in/New+York?F"
}
