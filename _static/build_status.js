url = "https://api.github.com/repos/tfiers/phd/actions/runs"

let was_building = false

function writeStatus(text) {
    let div = document.querySelector("#build-status")
    div.innerHTML = text
    div.title = `Last checked: ${(new Date()).toLocaleTimeString()}`
}

function updateStatus() {
    fetch(url)
    .then(res => res.json())
    .then(obj => {
        let last_run = obj["workflow_runs"][0]
        let status = last_run["status"]
        if (status == "completed") {
            if (was_building) {
                writeStatus("reload to get latest version")
            } else {
                writeStatus("latest version")
                setTimeout(updateStatus, 60 * 1000);
            }
        } else {
            fetch(last_run["jobs_url"])
            .then(res => res.json())
            .then(obj => {
                let live_logs = obj["jobs"][0]["html_url"]
                writeStatus(`<a href="${live_logs}">new version building …</a>`)
                was_building = true
                setTimeout(updateStatus, 1 * 1000);
            })
        }
    })
}

window.addEventListener('load', updateStatus)
