using EvidentialFlux
using Flux
using Flux.Optimise: AdamW, Adam
using GLMakie
using Statistics


f1(x) = sin.(x)
f2(x) = 0.01 * x .^ 3 .- 0.1 * x
f3(x) = x .^ 3
function gendata(id = 1)
    x = Float32.(-4:0.05:4)
    if id == 1
        y = f1(x) .+ 0.2 * randn(size(x))
    elseif id == 2
        y = f2(x) .* (1.0 .+ 0.2 * randn(size(x))) .+ 0.2 * randn(size(x))
    else
        y = f3(x) .+ randn(size(x)) .* 3.0
    end
    #scatterplot(x, y)
    x, y
end

"""
    predict_all(m, x)

Predicts the output of the model m on the input x.
"""
function predict_all(m, x)
    ŷ = m(x)
    γ, ν, α, β = ŷ[1, :], ŷ[2, :], ŷ[3, :], ŷ[4, :]
    # Correction for α = 1 case
    α = α .+ 1.0f-7
    au = uncertainty(α, β)
    eu = uncertainty(ν, α, β)
    (pred = γ, eu = eu, au = au)
end

function plotfituncert!(m, x, y, wband = true)
    ŷ, u, au = predict_all(m, x')
    #u, au = u ./ maximum(u), au ./ maximum(au)
    u, au = u ./ maximum(u) .* std(y), au ./ maximum(au) .* std(y)
    GLMakie.scatter!(x, y, color = "#5E81AC")
    GLMakie.lines!(x, ŷ, color = "#BF616A", linewidth = 5)
    if wband == true
        GLMakie.band!(x, ŷ + u, ŷ - u, color = "#5E81ACAC")
    else
        GLMakie.scatter!(x, u, color = :yellow)
        GLMakie.scatter!(x, au, color = :green)
    end
end

function plotfituncert(m, x, y, wband = true)
    f = Figure()
    Axis(f[1, 1])
    ŷ, u, au = predict_all(m, x')
    #u, au = u ./ maximum(u), au ./ maximum(au)
    #u, au = u ./ maximum(u) .* std(y), au ./ maximum(au) .* std(y)
    GLMakie.scatter!(x, y, color = "#5E81AC")
    GLMakie.lines!(x, ŷ, color = "#BF616A", linewidth = 5)
    if wband == true
        #GLMakie.band!(x, ŷ + u, ŷ - u, color = "#5E81ACAC")
        GLMakie.band!(x, ŷ + u, ŷ - u, color = "#EBCB8BAC")
        GLMakie.band!(x, ŷ + au, ŷ - au, color = "#A3BE8CAC")
    else
        GLMakie.scatter!(x, u, color = :yellow)
        GLMakie.scatter!(x, au, color = :green)
    end
    f
end

mae(y, ŷ) = Statistics.mean(abs.(y - ŷ))

x, y = gendata(3)
GLMakie.scatter(x, y)
GLMakie.lines!(x, f3(x))

epochs = 10000
lr = 0.005
m = Chain(Dense(1 => 100, relu), Dense(100 => 100, relu), Dense(100 => 100, relu), NIG(100 => 1))
#m(x')
opt = AdamW(lr, (0.89, 0.995), 0.001)
#opt = Flux.Optimiser(AdamW(lr), ClipValue(1e1))
pars = Flux.params(m)
trnlosses = zeros(epochs)
f = Figure()
Axis(f[1, 1])
for epoch in 1:epochs
    local trnloss = 0
    grads = Flux.gradient(pars) do
        ŷ = m(x')
        γ, ν, α, β = ŷ[1, :], ŷ[2, :], ŷ[3, :], ŷ[4, :]
        trnloss = Statistics.mean(nigloss(y, γ, ν, α, β, 0.01, 0.001))
        trnloss
    end
    Flux.Optimise.update!(opt, pars, grads)
    trnlosses[epoch] = trnloss
    if epoch % 2000 == 0
        println("Epoch: $epoch, Loss: $trnloss")
        plotfituncert!(m, x, f3(x), true)
    end
end

# The convergance plot shows the loss function converges to a local minimum
GLMakie.scatter(1:epochs, trnlosses)
# And the MAE corresponds to the noise we added in the target
ŷ, u, au = predict_all(m, x')
u, au = u ./ maximum(u), au ./ maximum(au)
println("MAE: $(mae(y, ŷ))")

# Correlation plot confirms the fit
GLMakie.scatter(y, ŷ)
GLMakie.lines!(-2:0.01:2, -2:0.01:2)

plotfituncert(m, x, y, true)
GLMakie.ylims!(-100, 100)

## Out of sample predictions to the left and right
xood = Float32.(-6:0.2:6);
plotfituncert(m, xood, f3(xood), true)
GLMakie.ylims!(-200, 200)
GLMakie.band!(4:0.01:6, -200, 200, color = "#8FBCBBB1")
GLMakie.band!(-6:0.01:-4, -200, 200, color = "#8FBCBBB1")
GLMakie.xlabel("hello")

## Out of sample predictions to the right
xood = Float32.(0:0.2:6);
plotfituncert(m, xood, f3(xood), true)
GLMakie.ylims!(-200, 200)

## Out of sample predictions to the left
xood = Float32.(-6:0.2:0);
plotfituncert(m, xood, f3(xood), true)
GLMakie.ylims!(-200, 200)
