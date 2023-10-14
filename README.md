# Angoka (暗号化)
Angoka is a tool to generate a hashed password that's made of the following two components:
- the content of files selected by you
- a password of your choice

By hashing these inputs a reproducible SHA3-512 hash is created.
Whenever the content of the supplied files changes or a wrong password is supplied,
the resulting hash becomes invalid and it isn't possible to, for example, open an encrypted partition.

## The Idea behind 'Angoka'
This program was intended to be used as a way to secure my fully encrypted Arch Linux setup from possible Evil Maid attacks.
In such a setup, the only unencrypted file(s) is the GRUB .efi executable.
As such, it is effectively the only file that could be modified in a harmful way.

If one were to hash that executable and their password and only unlock the partitions when the resulting hash matches,
they could severily reduce the risk of an Evil Maid attack going undetected.

### License

This project is licensed using the GPLv3 [License](LICENSE)
```
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
```

#### Sidenote:
This is a rewrite of [fphc](https://github.com/spflaumer/fphc) that fixes major bugs, features a more or less proper git commit history and is actually functional.