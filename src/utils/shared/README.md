# Utilities

Scripts and tools shared by supported Linux and macOS systems.

## Password-encrypted directories

`secure-dir.sh` manages EncFS-backed directories that remain encrypted and
unmounted by default. Creating a vault also creates a direnv portal; entering
the portal automatically prompts for the password if the vault is locked.

```bash
secure-dir.sh init personal
direnv allow "$HOME/Secure/personal"
cd "$HOME/Secure/personal"
cd files
```

The ciphertext and EncFS configuration live under
`~/.local/share/secure-dir/NAME/cipher`. The decrypted view exists only while
mounted at `~/Secure/NAME/files`.

Use `secure-dir.sh lock NAME` to unmount it. Vaults are not mounted by a boot or
login service, so they return to the locked state after a restart. EncFS and a
working FUSE implementation must be installed separately.
