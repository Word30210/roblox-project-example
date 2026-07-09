set windows-shell := ["powershell.exe", "-NoProfile", "-NoLogo", "-c"]
set dotenv-load := true

mprocs-args := '--names "rojo-sourcemap,darklua-process,rojo-serve" ' + \
    '"rojo sourcemap default.project.json -o sourcemap.json --watch" ' + \
    '"darklua process src dist --watch" ' + \
    '"rojo serve build.project.json"'

[unix]
default:
    @just --list

[windows]
default:
    @if ($PSVersionTable.PSVersion.Major -lt 7) { Write-Warning "PowerShell 7+ recommended. Current: $($PSVersionTable.PSVersion)" }
    @just --list

# sync assets to Studio (local)
[group('asset')]
assets:
    asphalt sync studio

# write assets to the .asphalt-debug/
[group('asset')]
assets-debug:
    asphalt sync debug

# upload assets to Roblox cloud
[group('asset')]
assets-upload:
    asphalt sync cloud

# check if all assets are synced (errors if any are outdated)
[group('asset')]
assets-check:
    asphalt sync cloud --dry-run

# refresh dependencies and build everything
[unix]
[group('dist')]
refresh:
    set -eu && \
    for pkg in packages/*/; do \
        ( \
            cd $pkg && \
            pesde install && \
            darklua process src dist \
        ); \
    done; \
    for place in places/*/; do \
        ( \
            cd $place && \
            pesde install && \
            rojo sourcemap default.project.json -o sourcemap.json && \
            darklua process src dist \
        ); \
    done; \
    pesde install

# refresh dependencies and build everything
[windows]
[group('dist')]
refresh:
    $ErrorActionPreference = "Stop"; \
    $PSNativeCommandUseErrorActionPreference = $true; \
    Get-ChildItem -Path packages -Directory | ForEach-Object { \
        Push-Location $_.FullName; \
        pesde install; \
        darklua process src dist; \
        Pop-Location; \
    }; \
    Get-ChildItem -Path places -Directory | ForEach-Object { \
        Push-Location $_.FullName; \
        pesde install; \
        rojo sourcemap default.project.json -o sourcemap.json; \
        darklua process src dist; \
        Pop-Location; \
    }; \
    pesde install

# remove all build outputs and installed dependencies (*_packages/, sourcemap.json, dist/, not pesde.lock)
[unix]
[group('dist')]
clean:
    set -eu && \
    for pkg in packages/*/; do \
        ( \
            cd $pkg && \
            rm -rf *_packages/ && \
            rm -rf dist/ \
        ); \
    done; \
    for place in places/*/; do \
        ( \
            cd $place && \
            rm -f sourcemap.json && \
            rm -rf *_packages/ && \
            rm -rf dist/ \
        ); \
    done

# remove all build outputs and installed dependencies (*_packages/, sourcemap.json, dist/, not pesde.lock)
[windows]
[group('dist')]
clean:
    $ErrorActionPreference = "Stop"; \
    $ConfirmPreference = "None"; \
    Get-ChildItem -Path packages -Directory | ForEach-Object { \
        Push-Location $_.FullName; \
        Remove-Item -Path *_packages -Recurse -Force -ErrorAction SilentlyContinue; \
        Remove-Item -Path dist -Recurse -Force -ErrorAction SilentlyContinue; \
        Pop-Location; \
    }; \
    Get-ChildItem -Path places -Directory | ForEach-Object { \
        Push-Location $_.FullName; \
        Remove-Item -Path sourcemap.json -Force -ErrorAction SilentlyContinue; \
        Remove-Item -Path *_packages -Recurse -Force -ErrorAction SilentlyContinue; \
        Remove-Item -Path dist -Recurse -Force -ErrorAction SilentlyContinue; \
        Pop-Location; \
    }

# run rojo + darklua watchers for the given place
[unix]
[group('dev')]
dev place:
    set -eu && cd places/{{place}} && mprocs {{mprocs-args}}

# run rojo + darklua watchers for the given place
[windows]
[group('dev')]
dev place:
    $ErrorActionPreference = "Stop"; Set-Location places/{{place}} && mprocs {{mprocs-args}}