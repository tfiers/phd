
"""
`ρ(x)` computes ``x / (exp(x) - 1)``,
but is numerically stable near, and defined at, ``x = 0``.

This function is used in some of the voltage-dependent 'gate opening/closing' rates in
Hodgkin-Huxley models (like αₙ and αₘ).

This corresponds to Brian and SciPy's "`exprel`",
which computes the inverse, ``\\frac{e^x - 1}{x}``.

The shape of `ρ(x)` is, loosely: "`╲__`" \\
i.e. for ``x < 0``, ``ρ(x) → -x`` and for ``x > 0``, ``ρ(x) → 0``. \\
Around `x = 0` it smoothly transitions between those two, with ``ρ(0) = 1``.
"""
ρ(x) =
    if (x == 0)  one(x)              # 0 / (exp(0) - 1)  ->  1
    else         x / expm1(x)  end

# Hodgkin-Huxley-type equations.
#
# - Adapted from https://brian2.readthedocs.io/en/stable/examples/COBAHH.html, which
#     references Brette et al. 2007, “Simulation of Networks of Spiking Neurons”
#     (appendix B.3.2: HH neurons), which in turn modified the equations from
#     Traub & Miles 1991, “Neuronal Networks of the Hippocampus”.
#     'COBA' stands for conductance-based (as opposed to simpler current-based models).
#
# - The Dayan & Abbott book has a good explanation of the Hodgkin-Huxley model (ch. 5).
#
HH = @eqs begin

    dv/dt = -(Iₘ+Iₛ)/Cₘ

    # Membrane current
    Iₘ =  ḡₗ     * (v-Eₗ)          # Passive leak current
        + ḡₖ *Pₖ * (v-Eₖ)          # Slow (persistent) K⁺ channels
        + ḡₙₐ*Pₙₐ* (v-Eₙₐ)         # Fast (transient) Na⁺ channels
    # Channel open probabilities:
    Pₖ  = n^4                      # '4 independent subunits' (see Dayan & Abbott)
    Pₙₐ = m^3 * h                  # '3 independent subunits and ball'
    dn/dt = αₙ * (1-n) - βₙ * n    # n ≈ P[K⁺ subunit open]
    dm/dt = αₘ * (1-m) - βₘ * m    # m ≈ P[Na⁺ subunit open]           (activation gate)
    dh/dt = αₕ * (1-h) - βₕ * h    # h ≈ P[Na⁺ ball not blocking pore] (inactivation gate)
    # Voltage-dependent opening (α) and closing (β) rates:
    αₙ = 0.032 /mV * 5mV * ρ( (v - 48mV) /  5mV)   /ms
    αₘ = 0.32  /mV * 4mV * ρ( (v - 50mV) /  4mV)   /ms
    αₕ = 0.128 *         exp( (v - 46mV) / 18mV)   /ms
    βₙ = 0.5   *         exp( (v - 53mV) / 40mV)   /ms
    βₘ = 0.28  /mV * 5mV * ρ(-(v - 23mV) /  5mV    /ms
    βₕ = 4 /       ( 1 + exp( (v - 23mV) /  5mV) ) /ms

    # Synaptic current
    Iₛ = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)
    dgₑ/dt = -gₑ/τₑ
    dgᵢ/dt = -gᵢ/τᵢ
end

#=
- When rendering these equations in latex, it should automatically add the used function:
  "…, where ρ(x) = " and then a bracket, with `x/(exp(x) - 1)  if x ≠ 0` and `1  if x = 0`.

- Pure variables (no diffeqs) -- if not recorded -- should be substituted in.
  (Simplest: just don't do `vars.I .=`, but `I =`. That only works for scalars though).
    - If not saving them, and thus not unpacking at start either, we need to hoist up
      the var assignments (before the diffeqs).

- mV and ms: we must know what units are when parsing.
  (nice rendering in latex then too. \mathrm{mV})

- Spike detection: not known yet how to specify (and how to best detect)
    - `v ≈ 20 mV && dv/dt > 0` for rising edge detection. (Or `dv/dt < 0` for falling).
    - `v > 20 mV && dv/dt ≈ 0` for peak detection.
        - Both of these are more suited to an adaptive timestep solver though, like SciML.
            - Using `ContinuousEventCallback`, with `v - 20mV` or `dv/dt - 0` the distance
              function.
  ..and then also a 'refractoriness' mechanism: don't emit spike again until..
    ('refractory' is bad name cause the real refractoriness (adaptation) is done by the
    model itself, the gating variables).
=#
