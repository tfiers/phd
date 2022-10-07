using DataStructures, Parameters, StatsBase

using PyPlot, DataFrames, ComponentArrays

df = DataFrame([(a=1, b=2), (a=2, b=2)])
cv = ComponentVector(a=3, b=8)

fig, ax = plt.subplots()
ax.plot(df.a, collect(cv))

repr(MIME("text/html"), df)

using JLD2

fn = tempname()*".jld2"
struct MyType
    x::String
end
jldsave(fn; somedata=(; a=2, b=""), p=MyType("yo"))
load(fn)
