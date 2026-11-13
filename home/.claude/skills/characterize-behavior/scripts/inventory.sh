#!/usr/bin/env bash
# Lists the entry points of a Laravel application as Markdown: the inventory of capabilities to characterize.
# Run it from the project root. It only reads: routes, commands, the schedule, and files.

set -euo pipefail

if [[ ! -f artisan ]]; then
    echo "Run this from the root of a Laravel application (no artisan file here)." >&2
    exit 1
fi

# An application that does not boot would list no routes and no schedule, which reads like "none".
if ! boot_error=$(php artisan about 2>&1 >/dev/null); then
    echo "The application does not boot, so its entry points cannot be listed:" >&2
    echo "$boot_error" >&2
    exit 1
fi

section() {
    printf '\n## %s\n\n' "$1"
}

# Prints the given lines as list entries in backticks, or "- none" when there are none.
print_list() {
    local lines
    lines=$(cat)

    if [[ -n $lines ]]; then
        sed 's/^/- `/; s/$/`/' <<<"$lines"
    else
        echo "- none"
    fi
}

# Prints the routes route:list returns as JSON, one line each: methods, URI, name, action, middleware.
print_routes() {
    php -r '
        $routes = json_decode(stream_get_contents(STDIN), true) ?? [];
        if ($routes === []) { echo "- none\n"; }
        foreach ($routes as $route) {
            printf("- `%s %s`%s → `%s` (%s)\n",
                $route["method"],
                $route["uri"],
                $route["name"] ? " `{$route["name"]}`" : "",
                $route["action"],
                implode(", ", (array) $route["middleware"]) ?: "no middleware");
        }
    '
}

# Lists the PHP files under a directory of app/.
print_classes() {
    local directory="app/$1"

    if [[ -d $directory ]]; then
        find "$directory" -name '*.php' | sort | print_list
    else
        echo "- none"
    fi
}

echo "# Entry points"

section "Routes of the application"
php artisan route:list --except-vendor --json | print_routes

section "Routes packages register for the application"
php artisan route:list --only-vendor --json | print_routes

section "Commands of the application"
{
    if [[ -d app/Console/Commands ]]; then
        find app/Console/Commands -name '*.php' | sort
    fi
    if [[ -f routes/console.php ]]; then
        grep -n "Artisan::command" routes/console.php | sed 's/^/routes\/console.php:/' || true
    fi
} | print_list

section "Schedule"
php artisan schedule:list

for kind in Jobs Listeners Subscribers Events Mail Notifications Livewire; do
    section "$kind"
    print_classes "$kind"
done

# Class-based Volt components extend Component; functional ones import Volt's functions.
section "Volt components"
if [[ -d resources/views ]]; then
    grep -rlE 'new class extends Component|use function Livewire\\Volt\\' resources/views | sort || true
fi | print_list

section "Broadcast channels"
if [[ -f routes/channels.php ]]; then
    grep -n "Broadcast::channel" routes/channels.php | sed 's/^/routes\/channels.php:/' || true
fi | print_list
