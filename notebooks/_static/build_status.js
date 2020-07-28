url = "https://api.github.com/repos/tfiers/voltage-to-wiring-sim/actions/runs"

function updateStatus() {
    fetch(url)
    .then(res => res.json())
    .then(obj => {
        let status = obj["workflow_runs"][0]["status"]
        let text
        if (status == "completed") {
            text = "latest version"
            setTimeout(updateStatus, 60*1000);
        } else {
            text = "new version building …"
            setTimeout(updateStatus, 500);
        }
        document.querySelector("#build-status").textContent = text
    })
}

window.addEventListener('load', updateStatus)
