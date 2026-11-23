#!/usr//bin/env bash
# ~/.local/bin/uwsm-status

echo "🔍 UWSM STATUS CHECK"
echo "===================="
echo ""

echo "1. Session Status:"
if uwsm check is-active &>/dev/null; then
    echo "   ✅ UWSM session is running"
else
    echo "   ❌ UWSM session is NOT running"
fi
echo ""

echo "2. Can Start New Session:"
if uwsm check may-start &>/dev/null; then
    echo "   ✅ Can start new session"
else
    echo "   ⚠️  Cannot start (session already running)"
fi
echo ""

echo "3. Wayland WM Service:"
if systemctl --user is-active --quiet wayland-wm-env@niri\\x2duwsm.desktop.service; then
    echo "   ✅ Active"
    echo "   Uptime: $(systemctl --user show wayland-wm-env@niri\\x2duwsm.desktop.service -p ActiveEnterTimestamp --value)"
else
    echo "   ❌ Inactive"
fi
echo ""

echo "4. Graphical Session Target:"
if systemctl --user is-active --quiet graphical-session.target; then
    echo "   ✅ Active"
else
    echo "   ❌ Inactive"
fi
echo ""

echo "5. Related Services:"
echo "   waybar:         $(systemctl --user is-active waybar.service 2>/dev/null || echo 'not found')"
echo "   swaync:         $(systemctl --user is-active swaync.service 2>/dev/null || echo 'not found')"
echo "   hypridle:       $(systemctl --user is-active hypridle.service 2>/dev/null || echo 'not found')"
echo "   hyprpaper:      $(systemctl --user is-active hyprpaper.service 2>/dev/null || echo 'not found')"
echo ""

echo "6. Environment Variables:"
echo "   WAYLAND_DISPLAY:    ${WAYLAND_DISPLAY:-not set}"
echo "   XDG_SESSION_TYPE:   ${XDG_SESSION_TYPE:-not set}"
echo "   XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP:-not set}"
echo "   AQ_DRM_DEVICES:     ${AQ_DRM_DEVICES:-not set}"
echo ""

echo "7. Niri Info:"
if command -v niri &>/dev/null; then
    echo "   Version: $(niri msg version | head -1)"
    echo "   Monitors: $(niri msg outputs | grep -c "Output")"
    echo "   Workspaces: $(niri msg workspaces | grep -c "Output")"
else
    echo "   niri not available"
fi
echo ""

echo "8. Recent Errors (last hour):"
errors=$(journalctl --user -p err --since "1 hour ago" --no-pager 2>/dev/null | wc -l)
if [ "$errors" -eq 0 ]; then
    echo "   ✅ No errors"
else
    echo "   ⚠️  $errors errors found"
    echo "   Run: journalctl --user -p err --since '1 hour ago'"
fi
