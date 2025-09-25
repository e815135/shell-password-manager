# Password Manager

Use `password_manager.sh` to create your own **local password manager** on **Linux**.

Install a Linux distribution, e.g. Ubuntu, on your machine. Save the `password_manager.sh` file and in a linux terminal, run:

```chmod 755 password_manager.sh```

You will then be able to access your password manager by running:

```./password_manager.sh```

When first opening the password manager, you will be prompted to create a **master passprase**. This is encrypted and saved in the file `.passphrase.hash`. Any passwords saved will be encrypted and saved in the file `passwords.enc`.

You will be prompted to select from 5 options:
- Add Password
- View Password
- Delete Password
- Update Master Passphrase
- Exit

Note that when viewing a password, the password is NOT printed to the terminal. Instead, it is added to your **clipboard**.

*'xclip' is a required dependency. To install, run:*
```sudo apt update && sudo apt install xclip```
