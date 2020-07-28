url = "https://api.github.com/repos/tfiers/voltage-to-wiring-sim/actions/runs"

function updateStatus() {
    fetch(url)
    .then(res => res.json())
    .then(obj => {
        let status = obj["workflow_runs"][0]["status"]
        let div = document.querySelector("#build-status")
        let oldText = div.textContent
        let newText
        const BUILDING = "new version building …"
        if (status == "completed") {
            if (oldText == BUILDING) {
                newText = "reload to get latest version"
            } else {
                newText = "latest version"
                setTimeout(updateStatus, 60*1000);
            }
        } else {
            newText = BUILDING
            setTimeout(updateStatus, 500);
        }
        div.textContent = newText
        div.title = `Last checked: ${(new Date()).toLocaleTimeString()}`
    })
}

window.addEventListener('load', updateStatus)
