Output docs/assets/terminal-demo.gif

Set Shell bash
Set Width 1200
Set Height 720
Set FontSize 20
Set TypingSpeed 25ms
Set Framerate 24
Set CursorBlink false
Set Theme "Catppuccin Frappe"
Set Padding 20
Set Margin 20
Set MarginFill "#303446"
Set WindowBar Colorful
Set BorderRadius 12

Hide
Type "mkdir -p /tmp/pvi-demo-bin generated docs/assets"
Enter
Type "cp zig-out/bin/version_info /tmp/pvi-demo-bin/package-version-info"
Enter
Type `export PATH="/tmp/pvi-demo-bin:$PATH"`
Enter
Type "rm -f generated/version-info.ts"
Enter
Type "clear"
Enter
Show

Type "package-version-info --help"
Enter
Sleep 3s

Ctrl+L
Sleep 500ms

Type "package-version-info generate --output generated/version-info.ts"
Enter
Sleep 2s

Ctrl+L
Sleep 500ms

Type "sed -n '1,22p' generated/version-info.ts"
Enter
Sleep 4s

Hide
Type "rm -f generated/version-info.ts /tmp/pvi-demo-bin/package-version-info"
Enter
