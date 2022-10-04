# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.13.7
#   kernelspec:
#     display_name: Julia 1.8.1 mysys
#     language: julia
#     name: julia-1.8-mysys
# ---

# # 2022-10-04 • Inspect curve-fitting procedure

# This is a continuation of the bottom of last notebook.
#
# (new nb, so easier to restart kernel).

# ## Imports

# +
#
# -

using MyToolbox

using VoltoMapSim

# ## Params

p = get_params(
    duration = 10minutes,
    p_conn = 0.04,
    g_EE = 1,
    g_EI = 1,
    g_IE = 4,
    g_II = 4,
    ext_current = Normal(-0.5 * pA/√seconds, 5 * pA/√seconds),
    E_inh = -80 * mV,
    record_v = [1:40; 801:810],
);

# ## Extracts from previous nb

# ### Load all STA's

# Skip this section if you want just one.

out = cached_STAs(p);  # Takes 15.2 seconds

(ct, STAs, shuffled_STAs) = out;
# `ct`: "connections to test table", or simply "connections table".

α = 0.05 
conns = ct.pre .=> ct.post
example_conn(typ) = conns[findfirst(ct.conntype .== typ)]
testconn(conn) = test_conn__model_STA(STAs[conn], shuffled_STAs[conn], α; p)
conn = example_conn(:exc)  # 139 => 1

STA = copy(STAs[conn]);

# ---

# ### Load 1 STA

cap = cachepath("2022-10-04__inspect_curve_fit", "STA");

# +
# savecache(cap, STA);
# -

STA = loadcache(cap);

# ### Model & fitting

Δt = p.sim.general.Δt::Float64
STA_duration = p.conntest.STA_window_length
t = collect(linspace(0, STA_duration, STA_win_size(p)))
p0_vec = collect(VoltoMapSim.p0)
lower, upper = VoltoMapSim.lower, VoltoMapSim.upper;

# +
linear_PSP_fm!(y, t, τ1, τ2) =
    if (τ1 == τ2)   @. @fastmath y = t * exp(-t/τ1)
    else            @. @fastmath y = τ1*τ2/(τ1-τ2) * (exp(-t/τ1) - exp(-t/τ2)) end

function turbomodel!(y, t, params, Δt)
    tx_delay, τ1, τ2, dip_loc, dip_width, dip_weight, scale = params
    T = round(Int, tx_delay / Δt) + 1
    y[T:end] .= @view(t[T:end]) .- tx_delay    
    @views linear_PSP_fm!(y[T:end], y[T:end], τ1, τ2)
    if (τ1 == τ2) max = τ1/ℯ
    else          max = τ2*(τ2/τ1)^(τ2/(τ1-τ2)) end
    @views y[T:end] .*= (1/max)
    y[1:T-1] .= 0
    y .-= @. @fastmath dip_weight * exp(-0.5*( (t-dip_loc)/dip_width )^2)
    y .*= scale
    y .-= mean(y)
    return nothing
end;
# -

using ForwardDiff

turbomodel!(y, t, params) = turbomodel!(y, t, params, Δt)
ft! = (y,p) -> turbomodel!(y, t, p)
y = similar(t)
cfg = ForwardDiff.JacobianConfig(ft!, y, p0_vec)
jac_turbomodel!(J, t, params) = ForwardDiff.jacobian!(J, ft!, y, params, cfg)
turbofit(STA; kw...) = curve_fit(turbomodel!, jac_turbomodel!, t, centre(STA), p0_vec; lower, upper, inplace = true, kw...);

@time turbofit(STA);  # compile

# ## Animate fit

using PyCall

@pyimport matplotlib.animation as anim

# +
# ] add Conda
# using Conda
# Conda.add("ffmpeg")
# After this, magically, `anim.writers.list()` includes ffmpeg.
# rcParams["animation.ffmpeg_path"]  > "ffmpeg"
# rcParams["animation.writer"] > "ffmpeg"

# Actually, `to_jshtml` saves the individual images. No ffmpeg necessary.

# +
# plt.ioff();  # run to disable GUI popping up
# -

PyPlot.isjulia_display[] = true;  # run again to clear out fig buffer :p

PyPlot.isjulia_display[] = false;   # If true, running the FuncAnimation crashes julia

rcParams["savefig.bbox"] = "standard";
# Default is "tight". But matplotlib animation sets it temporarily to None aka "standard".
# Note this only affects when saving, not with the default fig display.
# Hence the save-to-tmp below.

fig, ax = plt.subplots(figsize=(3,2.4))
plotsig(centre(STA) / mV, p; ax)
tms = collect(linspace(0, 100, 1000))
yy = similar(t);
y0 = similar(yy)
turbomodel!(y0, t, p0_vec)
tt = ax.set_title(" ")
ln, = ax.plot(tms, y0 / mV);

fig.subplots_adjust(left=0.16, right=0.94, bottom=0.24, top=0.86)
tmp = tempname() * ".png"
fig.savefig(tmp)
img = read(tmp);
# display("image/png", img)

# +
function update(i)
    if i == 0
        init()
    else
        res = turbofit(STA, maxIter = i + 1)
        turbomodel!(yy, t, res.param)
        ln.set_ydata(yy / mV)
        tt.set_text(f"MaxIter: {i:3d}")
    end
end

function init()
    ln.set_ydata(y0 / mV)
    tt.set_text(" ")
end;

@time update(1);  # more compilation.
# -

frames = [0:10; 20; 30; 50; 100; 150; 200; 250; 300; 1000];

an = anim.FuncAnimation(fig, update, frames, init);

# ### Exc STA

# +
# Here, we do manually what `ht = an.to_jshtml()` does, to have more control.
# (`to_jshtml` takes no kwargs)

htw = anim.HTMLWriter(embed_frames = true, fps = 10, default_mode = "reflect")
tmp = tempname() * ".html"
@time an.save(tmp, writer = htw)
ht = read(tmp, String)
display("text/html", ht)
# -

# :)
#
# Seems like we can get away with an order of magnitude less iterations, which is great news.

function anim_fit(STA)
    fig, ax = plt.subplots(figsize=(3,2.4))
    plotsig(centre(STA) / mV, p; ax)
    tms = collect(linspace(0, 100, 1000))
    yy = similar(t);
    y0 = similar(yy)
    turbomodel!(y0, t, p0_vec)
    tt = ax.set_title(" ")
    ln, = ax.plot(tms, y0 / mV);
    fig.subplots_adjust(left=0.16, right=0.94, bottom=0.24, top=0.86)
    function update(i)
        if i == 0
            init()
        else
            res = turbofit(STA, maxIter = i + 1)
            turbomodel!(yy, t, res.param)
            ln.set_ydata(yy / mV)
            tt.set_text(f"MaxIter: {i:3d}")
        end
    end
    function init()
        ln.set_ydata(y0 / mV)
        tt.set_text(" ")
    end
    frames = [0:10; 20; 30; 50; 100; 150; 200; 250; 300; 1000]
    an = anim.FuncAnimation(fig, update, frames, init)
    @time ht = an.to_jshtml(fps = 10, default_mode = "reflect")
    display("text/html", ht)
end;

# ### Inh STA

anim_fit(STAs[example_conn(:inh)])

# Here, 5 iterations was enough. The 300+ after that iterations changed the fit minimally.

# ### Unconn STA

STA = STAs[example_conn(:unconn)];

# +
# anim_fit(STAs[example_conn(:unconn)])

# this freezes the process. why.

# +
# below is result of unwrapping anim_fit function.
# That did work. So strange.
# -

@time ht = an.to_jshtml(fps = 10, default_mode = "reflect")
display("text/html", ht)

# (Btw, the artefact at the `tx_delay` discontinuity is probably [this one](https://tfiers.github.io/phd/nb/2022-09-11__Fit_function_to_STA.html#:~:text=%7C%3E%20ref_to_start!%20%20%20%23%20Zero%20at%20t_rel%20%3D%200.%20Avoids%20artefact%20at%20the%20%27tx_delay%27%20discontinuity.))
