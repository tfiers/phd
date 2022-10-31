
# Some syntax sketches.


# Nto1

m = @model begin

    n   = 1 * izh
    pₑ  = Nₑ * PoissonInput(λ)
    pᵢ  = Nᵢ * PoissonInput(λ)

    pₑ => n  @on_pre gₑ += Δgₑ
    pᵢ => n  @on_pre gᵢ += Δgᵢ
end

m = @model begin

    n   = 1 * izh
    Pₑ  = Nₑ * PoissonInput(λ)
    Pᵢ  = Nᵢ * PoissonInput(λ)

    connect(Pₑ => n, on_pre = :( gₑ += Δgₑ ))
    connect(Pᵢ => n, on_pre = :( gᵢ += Δgᵢ ))
end



# RNN

m = @model begin
    nₑ = Nₑ * izh
    nᵢ = Nᵢ * izh
    sₑ = connect(nₑ => (nₑ & nᵢ), p_conn, on_pre = :( post.gₑ += w ))
    sᵢ = connect(nᵢ => (nₑ & nᵢ), p_conn, on_pre = :( post.gᵢ += w ))
end

m = @model begin

    # Neurons
    nₑ = Nₑ * izh
    nᵢ = Nᵢ * izh
    n  = nₑ + nᵢ

    # Connections
    cₑ = connect(nₑ => n, p_conn, t_axon)
    cᵢ = connect(nᵢ => n, p_conn, t_axon)

    @on_spike_arrival
    cₑ  =>  post.gₑ += w
    cᵢ  =>  post.gᵢ += w
end




m = @model begin

    # Neurons
    nₑ = Nₑ * izh_neuron
    nᵢ = Nᵢ * izh_neuron
    n  = nₑ + nᵢ

    # Connections
    c = cₑ + cᵢ
    cₑ = connect(nₑ => n)
    cᵢ = connect(nᵢ => n)
    c.p_conn   = …
    c.tx_delay = …

    cₑ.@on_spike_arrival(post.gₑ += w)
    cᵢ.@on_spike_arrival(post.gᵢ += w)
end

# hm, confusing to just do *


    cₑ.@on_spike_arrival(izh_neuron.gₑ += w)
    cᵢ.@on_spike_arrival(izh_neuron.gᵢ += w)


# I like this (the `=> (nₑ & nᵢ`):

    # Neurons
    nₑ = Nₑ * izh_neuron
    nᵢ = Nᵢ * izh_neuron
    # Connections
    cₑ = connect(nₑ => (nₑ & nᵢ))
    cᵢ = connect(nᵢ => (nₑ & nᵢ))

# Aha! the post.gₑ stuff should already be there at the neuron def.
# (otherwise they're same as each other, "why you make diff here?").
#
# So.. what a neuron does to its outputs is property of that neuron,
# not the connection (Dale's law, ig).

# Oh! so it should.. be in the `@spike if …` block...
# hm, but then how to differentiate huh.
# I mean, how to DRY inh vs exc there.
# ig you'd separate spike condition and effects.
# so sth like
izh = f(diffeqs, spike_condition, after_spike: v=vₛ & u+=Δu)
izh_exc = similar(izh)
izh_exc.after_spike_arrives_at_output_neuron(output_neuron.gₑ += Δgₑ)
# yee.
# (:) breakthrough).

# mayb:
izh = @eqs begin

    dv/dt = (k*(v-vᵣ)*(v-vₜ) - u - I_syn + I_ext) / C
    …

    @spike if v > v_peak
        v = v_reset
        u += Δu

        @after axon_delay begin
            for on in output_neurons
                on.gₑ += Δg
            end
        end
    end
end
# (Ok, but we went back to ignoring exc/inh split problem here).

# ooh. that `@after delay` thing should be like a scheduled task in julia.
# (hehehe, more abuse).
# (cause now it looks like the `if` content will block execution, kinda).
# https://docs.julialang.org/en/v1/manual/asynchronous-programming/
# so yeah sth, mayb:
for on in output_neurons
    @async begin
        @wait sleep(axon_delay(self => on))
        on.gₑ += Δg
    end
end


# ah, the izh vs izh_exc split we could do with:

izh = @eqs begin
    dv/dt = (k*(v-vᵣ)*(v-vₜ) - u - I_syn + I_ext) / C
    …
    spike = v > vₛ
    if spike
        v = v_reset
        u += Δu
    end
end

izh_exc = @eqs begin

    $izh

    if spike
        # the above `for on in output_neurons` spiel;
        # --but that should be provided by lib...
    end
end
# hm so maybe we can keep our `@spike if v > vₛ`.
#
# there is syntax for providing a closure, and giving it an arg:

izh_exc.on_spike.after_axon_delay() do output_neuron
    output_neuron.gₑ += Δgₑ
end
# (starting to like more and more :)).

# btw a function "copy these eqs but add this" would be nice.
# (so you don't need the extra line of `izh_exc = copy(izh); izh_exc.prop = `).

# I gotta admit though, the `izh_exc.on_spike` above feels ambiguous: pre or post spike.
# So in that case, yes, spike events make sense to be on the connections after all.

# maybe sth like `on_self_spike` ? (i kinda like!)
# So the whole thing'd be:
# [stashing, ct here]

# a good name mayb:
izh.after_spike_arrives_at_output() do
    ...
end
