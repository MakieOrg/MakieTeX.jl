scene, layout = layoutscene(resolution = (500, 100), font = "CMU Serif Roman");
ax = layout[1, 1] = LAxis(scene)
hidexdecorations!(ax); hideydecorations!(ax);

xs = 0:0.5:10
ys = sin.(xs)
lin = lines!(ax, xs, ys, color = :blue)
sca = scatter!(ax, xs, ys, color = :red, markersize = 15px)

leg = layout[1, 2] = LLegend(scene, [lin, sca, [lin, sca]], ["a line", "some dots", " "], labelsize = 12);
leg.grid.content[1].content[3, 2] = MakieTeX.LTeX(leg.child, raw"\dot x = \frac{\partial x}{\partial t}");
scene
