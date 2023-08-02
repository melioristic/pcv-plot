using GeoMakie, CairoMakie
using Shapefile
using DataFrames
using Makie.GeometryBasics
using CSV
using Statistics
using NPZ

using ColorSchemes

palette = ColorSchemes.colorschemes[:mk_12]

include("core.jl")

path = "/Users/anand/Documents/data/pcv/IPCC-WGI-reference-regions-v4_shapefile/IPCC-WGI-reference-regions-v4.shp"

table = Shapefile.Table(path)

function plot_significance(ax, table, vegetation_type, xtreme)

    crop_location, forest_location = crop_forest_location()

    if vegetation_type == "crop"
        color = :grey80
        veg_location = crop_location
    else
        color = :grey80
        veg_location = forest_location
    end      
    
    scatter!(ax, veg_location , markersize = 2.5, color = color)

    
    ipcc_regions = ipcc_region()

    for i=1:length(table.geometry)
        list_points = Point2f[]
        if table.Name[i] in ipcc_regions
            
            ds_path = "/Users/anand/Documents/data/pcv/$(vegetation_type)_data/$(xtreme)"
            fname = [path for path in readdir(ds_path) if occursin("logreg_$(xtreme)_$(vegetation_type)_$(table.Name[i])",path)]
            fname_w = [path for path in readdir(ds_path) if occursin("logreg_winter_$(xtreme)_$(vegetation_type)_$(table.Name[i])",path)]

            if !isempty(fname)
            
                fname = fname[1]
                fname_w = fname_w[1]
                
                df = DataFrame(CSV.File(joinpath(ds_path, fname), header=1, delim="\t"))
                df_w = DataFrame(CSV.File(joinpath(ds_path, fname_w), header=1, delim="\t"))
                
                sig = winter_significance(df, df_w)
        
                if sig
                    if vegetation_type == "crop"
                        color = (palette[12], 0.3)
                    else
                        color = (palette[2], 0.3)
                    end                
                else
                    color = (:grey80, 0.3)
                end
                
                for point in table.geometry[i].points
                    p = (point.x, point.y)

                    push!(list_points, p)
                    
                end
                hm = poly!(ax, list_points, color = color, colormap=:viridis, strokecolor = :black, strokewidth=1)
            end
        end

    end

end


fig = Figure(resolution=(1200,1000))

ax1 = GeoAxis(fig[2,1], latlims=(25,75), dest = "+proj=cea", coastlines = true, xgridvisible = false, ygridvisible=false, title = "Low crop activity" )
ax2 = GeoAxis(fig[3,1], latlims=(25,75), dest = "+proj=cea", coastlines = true, xgridvisible = false, ygridvisible=false, title = "Low forest activity"  )
ax3 = GeoAxis(fig[4,1], latlims=(25,75), dest = "+proj=cea", coastlines = true, xgridvisible = false, ygridvisible=false, title = "High crop activity"  )
ax4 = GeoAxis(fig[5,1], latlims=(25,75), dest = "+proj=cea", coastlines = true, xgridvisible = false, ygridvisible=false, title = "High forest activity"  )


plot_significance(ax1, table, "crop", "low")
plot_significance(ax2, table, "forest", "low")
plot_significance(ax3, table, "crop", "high")
plot_significance(ax4, table, "forest", "high")

elem_1 = MarkerElement(color = :grey80, marker= :circle, markersize = 10, points=Point2f[(0.5,0.5)])
elem_2 = [PolyElement(color = (palette[12], 0.3), strokecolor = :black, strokewidth = 1, points = Point2f[(0, 0), (0, 1), (1,1), (1, 0)] )]
elem_3 = [PolyElement(color = (palette[2], 0.3), strokecolor = :black, strokewidth = 1, points = Point2f[(0, 0), (0, 1), (1,1), (1, 0)])]
elem_4 = [PolyElement(color = (:grey80, 0.3), strokecolor = :black, strokewidth = 1, points = Point2f[(0, 0), (0, 1), (1,1), (1, 0)])]

Legend(fig[1,1:end], [elem_1, elem_2, elem_3, elem_4], ["Vegetation", "Significant winter (Crop)", "Significant winter (Forest)", "Other Region"], orientation= :horizontal)

fig


save("images/significance_plot.pdf", fig)

