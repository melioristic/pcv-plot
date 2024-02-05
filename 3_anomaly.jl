using CairoMakie
using DataFrames
using CSV
using Statistics
using NPZ
using Random
using EvalMetrics
using StatsBase
using LaTeXStrings



include("core.jl")
palette

p_list = [val for (k, val) in palette if k!="pale_grey"]

# Simple schematic showing the methodology

regions = ipcc_regions()


vegetation_type = "crop"
xtreme = "high"

function get_anomaly(vegetation_type, xtreme, region)
    
    df = read_ori_data(vegetation_type, xtreme, region)
    
    if xtreme == "high"
        val = [10,20,30]
        color = palette["light_yellow"]
    elseif xtreme == "low"
        val = [12,22,32]
        color = palette["pink"]
    end

    if !ismissing(df)
        
        df = select(df, Not(["# year"]))

        ind = df[!, :lai_su] .==1
        
        mean_vec = mean.(filter.(!isnan, eachcol(df[ind,:])))
        
        out = mean_vec[1:end-1]

    else
        out = missing
    end
    return out
end


### Always run from here

ch = [1:13;]
cl = [1:13;]
fh = [1:13;]
fl = [1:13;]

name_ch = []
name_cl = []
name_fh = []
name_fl = []


for vegetation_type in ["forest", "crop"]
    for xtreme in ["low", "high"]
        log_reg = read_log_df(vegetation_type, xtreme)
        for region in regions
            
            out = get_anomaly(vegetation_type, xtreme, region)
            
            if !ismissing(out)
                col_name = "$(vegetation_type)_$(xtreme)_" * region *"_v3"
                if col_name in names(log_reg)
                    if (log_reg[!, col_name][3]>100*38) 
        
                        diff = log_reg[!, col_name][2] - log_reg[!, col_name][1]
                        threshold = 0.02
                        sig =  (diff > threshold) 


                        if sig
                            if vegetation_type == "forest"
                                if xtreme == "low"
                                    fl = hcat(fl, out)
                                    push!(name_fl, region)
                                else
                                    fh = hcat(fh, out)
                                    push!(name_fh, region)
                                end
                            else
                                if xtreme == "low"
                                    cl = hcat(cl, out)
                                    push!(name_cl, region)
                                else
                                    ch = hcat(ch, out)
                                    push!(name_ch, region)
                                end

                            end
                        end
                    end
                end
            end
        end
    end
end

vegetation_type = "crop"
xtreme = "low"

function sorted_anomaly(vegetation_type, xtreme, data, col_name)
    new_data = similar(data)
    new_col_name = similar(col_name)
    df = read_log_df(vegetation_type, xtreme)
    df = select(df, ["$(vegetation_type)_$(xtreme)_$(region)_v3" for region in col_name])
    diff = Vector(df[2, :]) - Vector(df[1, :])
    sorted_index = sortperm(diff, rev = false)

    for (i, sorted_i) in enumerate(sorted_index)
        new_data[:,i] = data[:, sorted_i]
        new_col_name[i] = col_name[sorted_i]
    end
    return new_data, new_col_name
end


cl = cl[:, 2:end]
ch = ch[:, 2:end]
fl = fl[:, 2:end]
fh = fh[:, 2:end]

cl, name_cl = sorted_anomaly("crop", "low", cl, name_cl)
ch, name_ch = sorted_anomaly("crop", "high", ch, name_ch)
fl, name_fl = sorted_anomaly("forest", "low", fl, name_fl)
fh, name_fh = sorted_anomaly("forest", "high", fh, name_fh)


xticks = ([1:12;], [L"$T_{w}$", L"$P_{w}$", L"$SM_{w}$ ", L"$SD_{w}$", L"$T_{sp}$", L"$P_{sp}$", L"$SM_{sp}$", L"$SD_{sp}$", L"$LAI_{sp}$", L"$T_{su}$", L"$P_{su}$", L"$SM_{su}$"] )

with_theme(theme_latexfonts()) do

    f = Figure(resolution=(1200,700), fontsize=18)
    ax_cl = Axis(f[1,1], title = L"LAI_{low}^{crop}",  yticks= ([1:5;],[ipcc_acronym[name] for name in name_cl]), xticks = ([1:13;], ["" for i=1:13]))
    ax_ch = Axis(f[2,1], title = L"LAI_{high}^{crop}", yticks= ([1:5;],[ipcc_acronym[name] for name in name_ch]), xticks = xticks)
    ax_fl = Axis(f[1,2], title = L"LAI_{low}^{forest}", yticks= ([1:8;],[ipcc_acronym[name] for name in name_fl]), xticks = ([1:13;], ["" for i=1:13]), xticklabelrotation=0*π/6)
    ax_fh = Axis(f[2,2], title = L"LAI_{high}^{forest}", yticks= ([1:5;],[ipcc_acronym[name] for name in name_fh]), xticks = xticks, xticklabelrotation=0*π/6, xgridvisible=false, ygridvisible=false)

    jointlimits = (-1,1)
    heatmap!(ax_cl, cl[1:end-1, :], colormap=:BrBG_5, colorrange = jointlimits)
    heatmap!(ax_ch, ch[1:end-1, :], colormap=:BrBG_5, colorrange = jointlimits)
    heatmap!(ax_fl, fl[1:end-1, :], colormap=:BrBG_5, colorrange = jointlimits)
    h = heatmap!(ax_fh, fh[1:end-1, :], colormap=:BrBG_5, colorrange = jointlimits)

    function plot_text(ax, data)
        for x=1:size(data)[1]
            for y=1:size(data)[2]
            text!(ax, 
                string(round(data[x,y], digits=2)), 
                position = [Point2f(x,y)], 
                align=(:center, :center),
                fontsize=14,
                color = ifelse(abs(data[x,y]) < 1.0, :grey20, :white),
                )
            end
        end
    end

    plot_text(ax_cl, cl[1:end-1, :])
    plot_text(ax_ch, ch[1:end-1, :])
    plot_text(ax_fl, fl[1:end-1, :])
    plot_text(ax_fh, fh[1:end-1, :])

    Colorbar(f[1:2,3], h)


    left_pad = 10
    top_pad = 10

    Label(
    f[1, 1, TopLeft()],
        "a)",
        font = "TeX Gyre Heros Bold",
        fontsize = 22,
        padding = (0, left_pad, top_pad, 0),
        halign = :right,
        )

    f

    Label(
    f[1, 2, TopLeft()],
        "b)",
        font = "TeX Gyre Heros Bold",
        fontsize = 22,
        padding = (0, left_pad, top_pad, 0),
        halign = :right,
        )


    Label(
    f[2, 1, TopLeft()],
        "c)",
        font = "TeX Gyre Heros Bold",
        fontsize = 22,
        padding = (0, left_pad, top_pad, 0),
        halign = :right,
        )

    Label(
    f[2, 2, TopLeft()],
        "d)",
        font = "TeX Gyre Heros Bold",
        fontsize = 22,
        padding = (0, left_pad, top_pad, 0),
        halign = :right,
    )
    f
    save("images/anomaly_v3.pdf", f)
    
end

