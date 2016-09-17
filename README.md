# exodus-linux-installer

Script for downloading/installing/uninstalling [Exodus][1] on Linux.

## Usage

```bash
$ git clone https://github.com/ExodusMovement/exodus-linux-installer.git ~/.exodus-installer
$ ln -s -f ~/.exodus-installer/exodus-installer.sh ~/.local/bin/exodus-installer
$ exodus-installer check
Exodus is not installed.
$ exodus-installer install 1.4.0
$ exodus-installer check
Exodus is installed. Version: 1.4.0
$ exodus-installer uninstall
```

# LICENSE

MIT

[1]: http://exodus.io/
