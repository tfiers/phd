function resizeRetinaFigures() {
    figures = document.querySelectorAll(".cell_output > img")
    Array.from(figures).forEach(img => {
        // Heuristic to determine whether figure was made with 
        // `IPython.display.set_matplotlib_formats('retina')`
        // (old notebooks contain figures where this wasn't the case).
        if (img.naturalWidth > 800) {
            img.width = img.naturalWidth / 2
        }
    })
}

window.addEventListener('load', resizeRetinaFigures)
