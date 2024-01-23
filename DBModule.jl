module DBModule

using XLSX

# Data structures
mutable struct LJData
    p::Array{Float64,1}
    ϱ::Array{Float64,1}
    T::Array{Float64,1}
    Y::Array{Float64,1}
    ΔY::Array{Float64,1}
    ref::Array{String,1}
    ref_id::Array{Int64,1}
    outlier::Array{Bool,1}
    reg::Array{String,1}
    reg_id::Array{Int64,1}
    Y_eos::Array{Float64,1}
    δY_eos::Array{Float64,1}
    Pj::Array{Float64,1}
    MAD::Array{Float64,1}
    LJData() = new()
end

mutable struct RefData
    author::Array{Any,1}
    journal::Array{Any,1}
    abbreviation::Array{Any,1}
    bib_id::Array{Any,1}
    volume::Array{Any,1}
    page::Array{Any,1}
    title::Array{Any,1}
    year::Array{Any,1}
    doi::Array{Any,1}
    RefData() = new()
end

# Function to extract literature data from the Excel database
function xlsx2refs(;path="C:/Daten/Seafile/LJ_Transport/literature_data/data/Data_Paper_All_Data FINAL.xlsx")
    # Read data
    xf = XLSX.readxlsx(path)
    sh = xf["Sources"][:]
    xf = nothing

    # Extract relevant data
    refdata = RefData()
    
    header = sh[1,:][:]

    refdata.author = sh[2:end,findfirst(header .== "Author")]
    refdata.journal = sh[2:end,findfirst(header .== "Journal")]
    refdata.abbreviation = sh[2:end,findfirst(header .== "Abbrevation")]
    refdata.abbreviation[ismissing.(refdata.abbreviation)] = repeat([""],sum(ismissing.(refdata.abbreviation)))
    refdata.bib_id = sh[2:end,findfirst(header .== "Latex")]
    refdata.volume = sh[2:end,findfirst(header .== "Volume")]
    refdata.page = sh[2:end,findfirst(header .== "Page")]
    refdata.title = sh[2:end,findfirst(header .== "Title")]
    refdata.year = sh[2:end,findfirst(header .== "Year")]
    refdata.doi = sh[2:end,findfirst(header .== "Doi")]

    return refdata
end

# Function to extract the data from the Excel database 
function load_db()
    # General variables
    props = ["eta","lambda","D"]
    syms = ["η","λ","D"]

    # Create Master Dict
    db = Dict{String,Any}()

    # Loop all properties
    for (i,prop) in enumerate(props)
        # Read excel
        db[prop] = xlsx2data(prop,syms[i])
    end

    return db
end

# Function to extract the data from the Excel database for one property
function xlsx2data(prop,sym;path="C:/Daten/Seafile/LJ_Transport/literature_data/data/Data_Paper_All_Data FINAL.xlsx")
    # Read data
    xf = XLSX.readxlsx(path)
    sh = xf[prop][:]
    xf = nothing

    # Initialize data structure
    dat = LJData()

    # Settings
    i_row_header = 6

    sh_dat = sh[i_row_header+1:end, :]
    sh_dat = sh_dat[(!).(all(ismissing.(sh_dat),dims=2))[:],1:end]
    sh_dat[ismissing.(sh_dat)] = NaN.*ones(sum(ismissing.(sh_dat)))
    sh_dat[sh_dat .== "Inf"] = Inf .* ones(sum(sh_dat .== "Inf"))
    sh_dat[sh_dat .== "NaN"] = NaN .* ones(sum(sh_dat .== "NaN"))
    header = sh[6,:]
    header[ismissing.(header)] = repeat([""], length(header[ismissing.(header)]))
    header = string.(strip.(header))

    # Extract data
    dat.p = Float64.(sh_dat[:, findfirst(header .== "p*")])
    dat.ϱ = Float64.(sh_dat[:, findfirst(header .== "ρ*")])
    dat.T = Float64.(sh_dat[:, findfirst(header .== "T*")])
    dat.Y = Float64.(sh_dat[:, findfirst(header .== "$(sym)")])
    dat.ΔY = Float64.(sh_dat[:, findfirst(header .== "Δ$(sym)")])
    dat.ref = strip.(string.(sh_dat[:, findfirst(header .== "Source")]))
    dat.ref_id = Int64.(sh_dat[:, findfirst(header .== "Source")+1])
    dat.outlier = Bool.(sh_dat[:, findfirst(header .== "(0 = Ausreißer)")])
    dat.reg = strip.(string.(sh_dat[:, findfirst(header .== "Region")+1]))
    # dat.reg_id = Int64.(sh_dat[:, findfirst(header .== "Region")])

    # EOS dependent data
    eos_i = "Kolafa"
    cols = findall(occursin.(lowercase(eos_i), lowercase.(header)))
    dat.Pj = sh_dat[:, cols[1]]
    dat.MAD = sh_dat[:, cols[2]]
    dat.Y_eos = sh_dat[:, cols[3]]
    dat.δY_eos = (dat.Y .- dat.Y_eos) ./ dat.Y_eos

    return dat
end

export LJData, RefData, xlsx2refs, load_db

end