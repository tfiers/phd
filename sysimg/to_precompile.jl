using PyPlot, DataFrames, ComponentArrays

df = DataFrame([(a=1, b=2), (a=2, b=2)])
cv = ComponentVector(a=3, b=8)

fig, ax = plt.subplots()
ax.plot(df.a, collect(cv))
