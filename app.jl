module App

# Load all required packages
using GenieFramework
@genietools
using PlotlyBase
using DataFrames
include("DBModule.jl")
using .DBModule

function convert2LJData(in)
    out = LJData()
    for f in fieldnames(LJData)
        setfield!(out, f, getfield(in, f))
    end
    return out
end

function plot_3D(data;what=data.Y.>0.0)
    what_confirmed = data.outlier .== 1
    what_outlier = data.outlier .== 0
    what_es = data.Y_eos .< 1e3 .&& log10.(abs.(data.Y_eos)) .> -10.0
    [
    PlotData(
        plot="scatter3d",
        x = data.T[what .&& what_confirmed],
        y = data.ϱ[what .&& what_confirmed], 
        z = data.Y[what .&& what_confirmed],
        xtype = "log",
        labels= ["T", "rho", "Y"],
        mode = "markers",
        marker = Dict(
            "size" => 4,
            "color" => "black",
        ),
        name = "Confirmed",
    ),
    PlotData(
        plot="scatter3d",
        x = data.T[what .&& what_outlier],
        y = data.ϱ[what .&& what_outlier], 
        z = data.Y[what .&& what_outlier],
        xtype = "log",
        labels= ["T", "rho", "Y"],
        mode = "markers",
        marker = Dict(
            "size" => 4,
            "color" => "red",
        ),
        name = "Outlier",
    ),
    (length(unique(data.T[what .&& what_es])) == 1 && length(unique(data.ϱ[what .&& what_es])) == 1) ? 
        PlotData(
            plot="scatter3d",
            x = data.T[what .&& what_es],
            y = data.ϱ[what .&& what_es],
            z = data.Y_eos[what .&& what_es],
            mode="markers",
            marker = Dict(
                "size" => 4,
                "line" => Dict(
                    "width" => 1,
                    "color" => "grey", 
                ),
                "color" => "white",
            ),
            opacity = 1.0,
            name = "Entropy Scaling",
        ) :
    (length(unique(data.T[what .&& what_es])) == 1 || length(unique(data.ϱ[what .&& what_es])) == 1) ?
        PlotData(
            plot="scatter3d",
            x = data.T[what .&& what_es],
            y = data.ϱ[what .&& what_es],
            z = data.Y_eos[what .&& what_es],
            mode="lines",
            line = Dict(
                "width" => 4,
                "color" => "grey", 
            ),
            opacity = 1.0,
            name = "Entropy Scaling",
        ) :
        PlotData(
            plot="mesh3d",
            x = data.T[what .&& what_es],
            y = data.ϱ[what .&& what_es],
            z = data.Y_eos[what .&& what_es],
            color = "grey",
            opacity = 0.5,
            name = "Entropy Scaling",
        ),
    ]
end

function update_statistics(data, ref)
    if ref == "all"
        N_ref = length(data.ref)
        N_outlier = sum(data.outlier .== 0)
        ratio_outlier = round(N_outlier / N_ref * 100,digits=1)
        Tmin = round(minimum(data.T),digits=2)
        Tmax = round(maximum(data.T),digits=2)
        rhomin = round(minimum(data.ϱ),digits=3)
        rhomax = round(maximum(data.ϱ),digits=3)
    else
        what = data.ref .== ref
        N_ref = sum(what)
        N_outlier = sum(data.outlier[what] .== 0)
        ratio_outlier = round(N_outlier / N_ref * 100,digits=1)
        Tmin = round(minimum(data.T[what]),digits=2)
        Tmax = round(maximum(data.T[what]),digits=2)
        rhomin = round(minimum(data.ϱ[what]),digits=3)
        rhomax = round(maximum(data.ϱ[what]),digits=3)
    end
    return N_ref, N_outlier, ratio_outlier, Tmin, Tmax, rhomin, rhomax
end

function create_data_table(data,refdat)
    refs = sort(unique(data.ref))
    what = [findfirst(iref .== refdat.abbreviation) for iref in refs]
    if any(isnothing.(what))
        error("References not found: ",refs[isnothing.(what)])
    end
    DataTable(DataFrame(
        "Abbrevation" => refdata.abbreviation[what],
        "Author" => refdata.author[what],
        "Year" => refdata.year[what],
        # "Journal" => refdata.journal[what],
        "DOI" => refdata.doi[what],
        "# Data Points" => [sum(data.ref .== iref) for iref in refs],
        "# Outliers" => [sum(data.ref .== iref .&& data.outlier .== 0) for iref in refs],
        "Outliers / %" => [round(sum(data.ref .== iref .&& data.outlier .== 0) / sum(data.ref .== iref) * 100,digits=1) for iref in refs],
        "T range" => [string(round(minimum(data.T[data.ref .== iref]),digits=2)," - ",round(maximum(data.T[data.ref .== iref]),digits=2)) for iref in refs],
    ))
end

# Load the database
print("Loading database...")

const db = load_db()
const refdata = xlsx2refs()

println(" done.")

# Reactive code
@app begin
    # Reactive variables
    @out msg = "The average is 0."
    @out props = [:eta, :lambda, :D]
    @out data_3D = [
        PlotData(),
    ]
    @out layout_3D = PlotlyBase.Layout()
    @out refs_select = [""]
    @out N_ref = 0.0
    @out N_outlier = 0.0
    @out ratio_outlier = 0.0
    @out Tmin = 0.0
    @out Tmax = 0.0
    @out rhomin = 0.0
    @out rhomax = 0.0
    @out table_data = DataTable(DataFrame())

    @in db_loaded::Bool = false
    @in load_db = false
    @in prop = :none
    @in ref = "all"

    # Private (non-reactive) variables
    @private data_all = Dict{String, Any}()
    @private data = LJData()
    @private pathrefs = 

    @onchange prop begin
        # data = data_all[string(prop)]
        data = db[string(prop)]

        ref = "all"
        refs_select = vcat("all",sort(unique(data.ref)))

        table_data = create_data_table(data,refdata)

        data_3D = plot_3D(data)
        layout_3D = PlotlyBase.Layout(
            scene = attr(
                xaxis_title = "T",
                yaxis_title = "rho",
                zaxis_title = "$(prop)",
                xaxis_type = "log",
                zaxis_type = "log",
            ),
            scene_aspectmode = "cube",
        )

        (N_ref, N_outlier, ratio_outlier, Tmin, Tmax, rhomin, rhomax) = update_statistics(data, ref)
    end

    @onchange ref begin
        if ref == "all"
            data_3D = plot_3D(data)
        else
            data_3D = plot_3D(data; what=data.ref .== ref)
        end    

        (N_ref, N_outlier, ratio_outlier, Tmin, Tmax, rhomin, rhomax) = update_statistics(data, ref)
    end
end

# Load the page
@page("/", "app.jl.html")
end
