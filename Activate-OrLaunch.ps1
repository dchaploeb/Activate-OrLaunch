
param(
    [string]$ProcessName,
    [string]$WindowTitle,
    [Parameter(Mandatory)]
    [string]$Command
)

if (-not $ProcessName -and -not $WindowTitle) {
    throw "Specify -ProcessName, -WindowTitle, or both."
}

Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;

public static class WindowTools {
    public delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr param);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr param);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hwnd);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hwnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int length);

    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hwnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hwnd, int command);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hwnd);
}
'@

$match = $null

[WindowTools]::EnumWindows({
    param($hwnd, $unused)

    if (-not [WindowTools]::IsWindowVisible($hwnd)) {
        return $true
    }

    $length = [WindowTools]::GetWindowTextLength($hwnd)
    if ($length -eq 0) { return $true }

    $title = [System.Text.StringBuilder]::new($length + 1)
    [void][WindowTools]::GetWindowText($hwnd, $title, $title.Capacity)

    if ($WindowTitle -and $title.ToString() -cnotmatch $WindowTitle) {
        return $true
    }

    if ($ProcessName) {
        [uint32]$processId = 0
        [void][WindowTools]::GetWindowThreadProcessId($hwnd, [ref]$processId)
        try {
            $proc = Get-Process -Id $processId -ErrorAction Stop
            if ($proc.ProcessName -ine $ProcessName) {
                return $true
            }
        } catch {
            return $true
        }
    }

    $script:match = $hwnd
    return $false
}, [IntPtr]::Zero) | Out-Null

if ($match) {
    if ([WindowTools]::IsIconic($match)) {
        [void][WindowTools]::ShowWindowAsync($match, 9)
    }
    [void][WindowTools]::SetForegroundWindow($match)
} else {
    Invoke-Expression $Command
}
