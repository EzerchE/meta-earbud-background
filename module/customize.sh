#!/system/bin/sh
ui_print "Meta Glasses Earbud Background"
ui_print "Supported Meta AI: 289.0.0.25.162"
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/meta-inject" 0 0 0755
set_perm "$MODPATH/configure.sh" 0 0 0700
if [ -f "$MODPATH/background.template.js" ]; then
  # An upgrade must not silently reuse a previous device-specific bundle.
  rm -f "$MODPATH/background.js"
  ui_print "Configuration required after install: see INSTALL.md"
fi
