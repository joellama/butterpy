using Random
using Statistics

export Spot, Region, modulate

"""
Siderial rotation period at the equator
"""
const PROT_SUN = 24.5
const OMEGA_SUN = 2 * π / PROT_SUN / 86400

struct Spot{T <: Number}
    nday::Int # day index
    lat::T
    lon::T
    Φmax::T
    area_max::T
end

struct Region{T <: Number}
    spots::Vector{<:Spot}
    duration::T
    inclination::T
    ω::T
    Δω::T
    equatorial_period::T
    τ_emergence::T
    τ_decay::T
end

function Region(spots::AbstractVector{Spot};
    duration = maximum([s.nday for s in spots]),
    alpha_med = 0.0001,
    inclination = asin(rand()),
    ω = 1.0,
    Δω = 0.2,
    τ_decay = 5.0,
    threshold = 0.1)
    
    ω *= OMEGA_SUN
    Δω *= OMEGA_SUN
    eq_per = 2π / ω / 86400
    τ_emergence = max(2.0, eq_per * τ_decay / 5)
    τ_decay *= eq_per


    filt(s) = (s.nday < duration) && (s.Φmax > threshold)
    spots = filter(filt, spots)
    Φmax = [s.Φmax for s in spots]
    area_max = alpha_med .* Φmax ./ median(Φmax)
    spots = [Spot(s.nday, s.lat, s.lon, s.Φmax, a) for (s, a) in zip(spots, area_max)]

    return Region(spots, promote(duration, inclination, ω, Δω, eq_per, τ_emergence, τ_decay)...)
end

Base.broadcastable(r::Region) = Ref(r)
Base.length(r::Region) = length(r.spots)
Base.size(r::Region) = size(r.spots)
Base.size(r::Region, i) = size(r.spots, i)

"""
    diffrot(ω₀, Δω, lat)

Default differental rotation function

Returns angular velocity as a function of latitude [0°, 90°]
"""
@inline diffrot(ω₀, Δω, lat) = ω₀ - Δω * sin(lat)^2

function modulate(spot::Spot, t,
    τ_emergence, τ_decay,
    ω, Δω, inclination, diffrot_func = diffrot)
    # Get spot area
    tt = t - spot.nday
    area = spot.area_max
    timescale = tt < 0 ? τ_emergence : τ_decay
    
    area *= exp(-(tt / timescale)^2 / 2)

    # rotation rate
    phase = diffrot(ω, Δω, spot.lat) * t * 86400 + spot.lon

    # foreshortening
    cos_beta = cos(inclination) * sin(spot.lat) + sin(inclination) * cos(spot.lat) * cos(phase)

    return -area * max(cos_beta, 0.0)
end

"""
    modulate(::Spots, time)

Modulate the flux for all spots
"""
function modulate(r::Region, t)
    dFlux = sum(modulate.(r.spots, t, r.τ_emergence, r.τ_decay, r.ω, r.Δω, r.inclination))
    return dFlux
end
