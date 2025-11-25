// ==============================================
// REPORT ISSUE / FEEDBACK SYSTEM
// ==============================================

// Character counter for report message
document.addEventListener('DOMContentLoaded', () => {
    const reportMessage = document.getElementById('reportMessage');
    if (reportMessage) {
        reportMessage.addEventListener('input', () => {
            const count = reportMessage.value.length;
            document.getElementById('charCount').textContent = count;

            // Limit to 500 characters
            if (count > 500) {
                reportMessage.value = reportMessage.value.substring(0, 500);
                document.getElementById('charCount').textContent = 500;
            }
        });
    }
});

// Submit report via SNS
async function submitReport() {
    const type = document.getElementById('reportType').value;
    const message = document.getElementById('reportMessage').value.trim();
    const statusDiv = document.getElementById('reportStatus');

    // Validation
    if (!type || !message) {
        statusDiv.innerHTML = '<div class="alert alert-warning"><i class="bi bi-exclamation-triangle me-2"></i>Please fill in all fields</div>';
        return;
    }

    // Show loading
    statusDiv.innerHTML = '<div class="alert alert-info"><i class="bi bi-hourglass-split me-2"></i>Sending your report...</div>';

    try {
        const response = await fetch('/api/report', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                type: type,
                message: message,
                timestamp: new Date().toISOString(),
                user_agent: navigator.userAgent
            })
        });

        const data = await response.json();

        if (response.ok) {
            // Success
            statusDiv.innerHTML = '<div class="alert alert-success"><i class="bi bi-check-circle me-2"></i>Report sent successfully! We will get back to you soon.</div>';

            // Clear form
            document.getElementById('reportForm').reset();
            document.getElementById('charCount').textContent = '0';

            // Close modal after 2 seconds
            setTimeout(() => {
                const modal = bootstrap.Modal.getInstance(document.getElementById('reportModal'));
                if (modal) {
                    modal.hide();
                    statusDiv.innerHTML = '';
                }
            }, 2000);
        } else {
            // Error from server
            const errorMsg = data.error || 'Failed to send report';
            statusDiv.innerHTML = '<div class="alert alert-danger"><i class="bi bi-x-circle me-2"></i>Error: ' + errorMsg + '</div>';
        }
    } catch (error) {
        console.error('Error submitting report:', error);
        statusDiv.innerHTML = '<div class="alert alert-danger"><i class="bi bi-x-circle me-2"></i>Network error. Please try again later.</div>';
    }
}

// Make submitReport available globally
window.submitReport = submitReport;
