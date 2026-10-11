# moonraker-bosun

[日本語](README.ja.md)

A tool to track Klipper configuration files and Moonraker database contents in git, through the Moonraker API.
The command name is `bosun`.

* Records the contents fetched from the host in a dedicated branch, `host-tracking`
* Applies locally edited configuration to the host only after checking that nothing has changed there
* Never writes to the host while printing, and never restarts Klipper (no `RESTART`)
* Depends only on the Moonraker API, not on any web UI (Mainsail, Fluidd, ...) or distribution (MainsailOS, ...)

This README is a summary. The full specification of each command is in [README.ja.md](README.ja.md) (Japanese),
and the design of the tracking (how git is used) is in [docs/design.md](docs/design.md) (Japanese).

## Requirements

* Ruby 3.4 or later
* git
* Moonraker API reachable without authentication
  * Moonraker authentication (API keys, etc.) is not supported yet. bosun is meant to be used within a local network or a VPN (Tailscale, etc.)

## Installation

```bash
gem install moonraker-bosun
```

## Usage

Prepare a git repository to manage the configuration, and run `bosun` inside it.
`bosun` uses `config/` and `backup/` of the git repository containing the current directory.

```bash
mkdir my-printer && cd my-printer
git init
git commit --allow-empty -m "Initialize"  # bosun expects HEAD to have a commit

export MOONRAKER_BASE_URL=http://<host>:7125
bosun ls                                  # list configuration files on the host
bosun add printer.cfg moonraker.conf      # start tracking
bosun backup                              # back up the Moonraker DB (web UI settings, etc.)
```

After that:

```bash
bosun status         # show the state of the host and local files
bosun pull           # fetch changes made on the host (SAVE_CONFIG, etc.)
vi config/printer.cfg && git commit -am "Change configuration"
bosun push -n        # show what would be applied to the host
bosun push           # apply to the host
```

```
$ bosun push
Update: printer.cfg

Uploaded: printer.cfg
Fetched: config/printer.cfg
Committed to host-tracking: b98b680
  changed: config/printer.cfg
Merged into main

To activate the applied configuration, restart from the web UI or elsewhere (RESTART for Klipper). bosun does not restart
```

### Environment variables

* `MOONRAKER_BASE_URL`: the base URL of the Moonraker API (e.g. `http://mainsailos.local:7125`)
* `LC_ALL`, `LC_MESSAGES`, `LANG`: messages are shown in Japanese if the first one set starts with `ja`, and in English otherwise
  * Messages recorded in git (merge commits, etc.) are always in English

## Commands

| Command | Description |
| --- | --- |
| `bosun roots` | List root directories on the host |
| `bosun ls` | List files on the host |
| `bosun get FILE...` | Download files from the host into the current directory (without tracking) |
| `bosun add FILE...` | Fetch files from the host and start tracking them |
| `bosun pull` | Fetch all tracked files from the host |
| `bosun status` | Show the state of configuration files on the host and locally |
| `bosun audit` | Check sync states by comparing contents, and check the invariants of `host-tracking` |
| `bosun diff` | Show differences between the last fetched contents and local (`HEAD`), i.e. what `push` would apply |
| `bosun push` | Apply local changes to the host |
| `bosun forget FILE...` | Stop tracking files, keeping them on the host |
| `bosun rm FILE...` | Delete files on the host and stop tracking them |
| `bosun backup` | Back up Moonraker DB contents into `backup/moonraker-db/` |
| `bosun export` | Write the files fetched as of a point in time to a directory |

Run `bosun <command> --help` for the options of each command.

### How tracking works

* `add`, `pull`, `push`, `forget`, `rm` and `backup` commit what was fetched from the host to the `host-tracking` branch,
  then merge it into the current branch
  * `host-tracking` contains only what was actually fetched from the host
  * Edit files on your working branch (e.g. `main`) and apply them with `push`
* If a merge conflicts, resolve it and `git commit`, or abort it with `git merge --abort`
* Push `host-tracking` to your remote together with `main` (`git push origin main host-tracking`); bosun does not push

### Writing to the host

* bosun writes only to files that Moonraker reports as `rw` (symbolic links such as `mainsail.cfg` are not)
* `push` and `rm` abort if the printer is printing, or if the files on the host have changed since they were last fetched
* Files are deleted on the host only by `bosun rm`

## Development

Ruby 3.4 or later is supported. Only the standard library is used at runtime; gems for development
(minitest, RuboCop, WEBrick, ...) are managed with `Gemfile`.
The development environment is Ruby 3.4.11 (`.ruby-version`) with its bundled Bundler (2.6.9).

```bash
bundle install
bundle exec rake               # tests and RuboCop
bundle exec rake test          # tests
bundle exec rake rubocop       # RuboCop
```

## License

[MIT License](LICENSE)
