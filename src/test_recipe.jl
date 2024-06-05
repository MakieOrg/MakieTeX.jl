@recipe(TestMe) do scene
    Attributes(
        one = Makie.automatic,
        two = 2,
        three = "3"
    )
end

Makie.plot!(p::TestMe) = lines!(p, p.args...; p.attributes...)

Makie.used_attributes(p::Type{<: TestMe}, ::AbstractVector{<: Point2f}) = (:one, :two, :three, :color)

function Makie.convert_arguments(p::Type{<: TestMe}, args::AbstractVector{<: Point2f}; one = 1, two = 2, three = 3, color = :red) 
    @show one two three color
    return (args,)
end

testme(rand(Point2f, 10));