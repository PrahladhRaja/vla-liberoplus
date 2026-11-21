#!/usr/bin/env bash
# Manage the Windows Task Scheduler entry that starts nightly.sh at WINDOW_START every day (WSL only).
#   schedule.sh install    register (or update) the task
#   schedule.sh remove     delete the task
#   schedule.sh pause      disable the task: no nightly runs until resumed (a run in progress continues;
#                          end it with stop.sh)
#   schedule.sh resume     re-enable the task; the next night continues where the evaluation stopped
#   schedule.sh status     show the task's state, last/next run
#   schedule.sh test       run the task now (nightly.sh exits at once outside the window)
# The task runs as your Windows user while you are logged on (a locked screen is fine), launches WSL
# with no console window, and can wake the PC from sleep.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
source "$HERE/config.sh"
PS="powershell.exe -NoProfile -NonInteractive -Command"
DISTRO=${WSL_DISTRO_NAME:-Ubuntu}
AT=$(date -d "$WINDOW_START" +%I:%M%p)

case "${1:-}" in
  install)
    $PS "
      \$action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\conhost.exe' \`
        -Argument '--headless C:\Windows\System32\wsl.exe -d $DISTRO -u $(whoami) --exec /bin/bash $HERE/nightly.sh'
      \$trigger = New-ScheduledTaskTrigger -Daily -At $AT
      \$settings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable -AllowStartIfOnBatteries \`
        -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 12)
      Register-ScheduledTask -TaskName '$TASK_NAME' -Action \$action -Trigger \$trigger -Settings \$settings -Force \`
        -Description 'Runs $HERE/nightly.sh ($WINDOW_START-$WINDOW_END)' | Out-Null
      Write-Output 'Installed: $TASK_NAME (daily at $WINDOW_START)'
    " | tr -d '\r'
    ;;
  remove)
    $PS "Unregister-ScheduledTask -TaskName '$TASK_NAME' -Confirm:\$false; Write-Output 'Removed: $TASK_NAME'" | tr -d '\r'
    ;;
  pause)
    $PS "Disable-ScheduledTask -TaskName '$TASK_NAME' | Out-Null; Write-Output 'Paused: no nightly runs until: schedule.sh resume'" | tr -d '\r'
    flock -n "$HERE/.run.lock" true || echo "Note: an evaluation is running now and will continue; to end it: $HERE/stop.sh"
    ;;
  resume)
    $PS "Enable-ScheduledTask -TaskName '$TASK_NAME' | Out-Null; \$i = Get-ScheduledTaskInfo -TaskName '$TASK_NAME'; Write-Output ('Resumed; next run: ' + \$i.NextRunTime)" | tr -d '\r'
    ;;
  status)
    $PS "
      \$t = Get-ScheduledTask -TaskName '$TASK_NAME' -ErrorAction SilentlyContinue
      if (-not \$t) { Write-Output 'Not installed'; exit }
      \$i = \$t | Get-ScheduledTaskInfo
      Write-Output ('State: ' + \$t.State + ' | last run: ' + \$i.LastRunTime + ' (result ' + \$i.LastTaskResult + ') | next run: ' + \$i.NextRunTime)
    " | tr -d '\r'
    ;;
  test)
    $PS "Start-ScheduledTask -TaskName '$TASK_NAME'; Write-Output 'Started; see $HERE/nightly.log'" | tr -d '\r'
    ;;
  *)
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
