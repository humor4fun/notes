Google Drive won't accept symlinks for syncing but you can do the opposite: Create a folder in your Drive path, then symlink it back to the location you want to sync data from.

1. Move desktop files to the destination (in gdrive)
2. Delete the source folder
3. Run one of these commands

  * Windows: Run this command from cmd.exe (run as administrator) 
  ```
  mklink /D "C:\Users\uname\Desktop" "C:\Users\uname\Google Drive\path\to\folder\storage\Desktop-win"
  ```
  * Mac: Run this command from terminal 
  ```
  ln -s ~/Google\ Drive/path/to/folder/storage/Desktop-mac ~/Desktop
  ```

This will make, in your Google Drive, `GDrive:\path\to\folder\storage\[Desktop-win, Desktop-mac]` so your files on your desktop are in Google and also still on your desktop.
