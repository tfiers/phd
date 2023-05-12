
## How to compile

`git clone` with the `--recurse-submodules` option,
so that the dependency ['totex'](https://github.com/tfiers/totex) is included.

[Installed][1] [`TinyTeX-1`][2] with:
```
wget -qO- "https://yihui.org/tinytex/install-bin-unix.sh" | sh
```
[1]: https://yihui.org/tinytex/#installation
[2]: https://github.com/rstudio/tinytex-releases

Then installed these extra packages in addition to the included ones: \
`$ tlmgr install --with-doc cm-super silence printlen capt-of ltablex relsize xurl chngcntr texdoc pgfplots memoir textcase pdfpages placeins caption microtype multirow makecell siunitx pdflscape biblatex bookmark cleveref`

Then: `xelatex main.tex` (note, `xelatex`, not `xetex`)


For continous compilation: `latexmk -pvc -pdfxe main.tex`.
