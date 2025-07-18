#!/bin/bash

# FASTAPISCRIPT Failure Notification Script
# Sends notifications when FASTAPISCRIPT runner fails

set -euo pipefail

SERVICE_NAME="$1"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/var/log/fastapiscript/notifications.log"
FAILURE_COUNT_FILE="/tmp/fastapiscript-failure-count"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Function to log messages
log_message() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

# Function to get failure count
get_failure_count() {
    if [ -f "$FAILURE_COUNT_FILE" ]; then
        cat "$FAILURE_COUNT_FILE"
    else
        echo "0"
    fi
}

# Function to increment failure count
increment_failure_count() {
    local current_count=$(get_failure_count)
    local new_count=$((current_count + 1))
    echo "$new_count" > "$FAILURE_COUNT_FILE"
    echo "$new_count"
}

# Function to reset failure count
reset_failure_count() {
    echo "0" > "$FAILURE_COUNT_FILE"
}

# Function to get service information
get_service_info() {
    local exit_code=$(systemctl show "$SERVICE_NAME" --property=ExecMainStatus --value)
    local last_log=$(journalctl -u "$SERVICE_NAME" --lines=5 --no-pager --since="10 minutes ago")
    
    echo "Exit Code: $exit_code"
    echo "Recent logs:"
    echo "$last_log"
}

# Function to send email notification
send_email() {
    local subject="$1"
    local body="$2"
    local recipient="sopewenike@gmail.com"  # Change this to sam@brainzcode.com
    
    if command -v mail >/dev/null 2>&1; then
        echo "$body" | mail -s "$subject" "$recipient"
        log_message "Email notification sent to $recipient"
    else
        log_message "WARNING: 'mail' command not found, skipping email notification"
    fi
}

# Function to send Slack notification
send_slack() {
    local message="$1"
    local webhook_url="YOUR_SLACK_WEBHOOK_URL"  # Replace with your Slack webhook URL
    
    if [ "$webhook_url" != "YOUR_SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$message\"}" \
            "$webhook_url" >/dev/null 2>&1 && \
        log_message "Slack notification sent" || \
        log_message "Failed to send Slack notification"
    else
        log_message "Slack webhook URL not configured"
    fi
}

# Function to send desktop notification
send_desktop_notification() {
    local title="$1"
    local message="$2"
    
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$message"
        log_message "Desktop notification sent"
    fi
}

# Function to log to syslog
log_to_syslog() {
    local message="$1"
    logger -t "fastapiscript-monitor" "$message"
}

# Main execution
main() {
    log_message "=== FASTAPISCRIPT Failure Notification Started ==="
    log_message "Service: $SERVICE_NAME"
    
    # Get current failure count
    local failure_count=$(increment_failure_count)
    log_message "Current failure count: $failure_count"
    
    # Get service information
    local service_info=$(get_service_info)
    
    # Create notification message
    local subject="FASTAPISCRIPT Service Failure Alert"
    local message="Service: $SERVICE_NAME
Failure Count: $failure_count
Timestamp: $TIMESTAMP

$service_info

This is failure #$failure_count for the FASTAPISCRIPT runner service."
    
    # Send notifications based on failure count
    if [ "$failure_count" -eq 1 ]; then
        log_message "First failure detected - logging only"
        log_to_syslog "FASTAPISCRIPT service $SERVICE_NAME failed (attempt 1)"
        
    elif [ "$failure_count" -eq 2 ]; then
        log_message "Second failure detected - sending notifications"
        
        # Send all types of notifications
        send_email "$subject - Critical (2nd Failure)" "$message"
        # send_slack ":warning: *FASTAPISCRIPT Critical Failure*\n\`\`\`$message\`\`\`"
        send_desktop_notification "$subject" "FASTAPISCRIPT service failed twice!"
        log_to_syslog "CRITICAL: FASTAPISCRIPT service $SERVICE_NAME failed twice"
        
    elif [ "$failure_count" -gt 2 ]; then
        log_message "Multiple failures detected ($failure_count) - sending escalated notifications"
        
        # Send escalated notifications
        local escalated_subject="$subject - URGENT (${failure_count} failures)"
        local escalated_message="URGENT: FASTAPISCRIPT service has failed $failure_count times!

$message

Please investigate immediately."
        
        send_email "$escalated_subject" "$escalated_message"
        # send_slack ":rotating_light: *URGENT: FASTAPISCRIPT Multiple Failures*\nFailure count: $failure_count\n\`\`\`$message\`\`\`"
        send_desktop_notification "$escalated_subject" "FASTAPISCRIPT service failed $failure_count times!"
        log_to_syslog "URGENT: FASTAPISCRIPT service $SERVICE_NAME failed $failure_count times"
    fi
    
    # If failures exceed a threshold, consider disabling the timer
    if [ "$failure_count" -ge 5 ]; then
        log_message "CRITICAL: Too many failures ($failure_count), consider manual intervention"
        # Optionally disable the timer to prevent further failures
        # systemctl disable fastapiscript.timer
    fi
    
    log_message "=== FASTAPISCRIPT Failure Notification Completed ==="
}

# Function to handle success (call this from a success hook if needed)
handle_success() {
    local current_count=$(get_failure_count)
    if [ "$current_count" -gt 0 ]; then
        log_message "Service recovered after $current_count failures - resetting counter"
        reset_failure_count
        
        # Send recovery notification if there were previous failures
        local message="FASTAPISCRIPT service $SERVICE_NAME has recovered after $current_count failures at $TIMESTAMP"
        send_email "FASTAPISCRIPT Service Recovery" "$message"
        # send_slack ":white_check_mark: *FASTAPISCRIPT Service Recovered*\n$message"
        log_to_syslog "FASTAPISCRIPT service $SERVICE_NAME recovered after $current_count failures"
    fi
}

# Check if called with success parameter
if [ "${1:-}" = "success" ]; then
    handle_success
else
    main "$@"