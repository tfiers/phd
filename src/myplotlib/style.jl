export mplstyle

mplstyle = Dict(
    "axes.spines.top"      => false,
    "axes.spines.right"    => false,
    "axes.grid"            => true,
    "axes.axisbelow"       => true,  # Grid _below_ patches (such as histogram bars), not on top.
    "axes.grid.which"      => "both",   
    "grid.linewidth"       => 0.5,        # These are for major grid. Minor grid styling
    "grid.color"           => "#E7E7E7",  # is set in `set!`.
    
    "xtick.direction"      => "in",
    "ytick.direction"      => "in",
    "xtick.labelsize"      => "small", # Default is "medium"
    "ytick.labelsize"      => "small", # idem
    "legend.fontsize"      => "small", # Default is "medium"
    "axes.titlesize"       => "medium",
    "axes.labelsize"       => 9,
    "xaxis.labellocation"  => "left",
    "axes.titlelocation"   => "right",

    "legend.borderpad"     => 0.6,
    "legend.borderaxespad" => 0.2,
    
    "lines.solid_capstyle" => "round",
    
    "figure.facecolor"     => "white",
    "figure.figsize"       => (4, 2.4),
    "figure.dpi"           => 200,
    "savefig.dpi"          => "figure",
    "savefig.bbox"         => "tight",
    
    "axes.autolimit_mode"  => "data" , 
    "axes.xmargin"         => 0, 
    "axes.ymargin"         => 0,
)
