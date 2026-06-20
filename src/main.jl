using GDPGrowth
using ArgParse

using Plots

function parse_args_custom(args)
  s = ArgParseSettings()
  @add_arg_table! s begin
    "--countries"
    help = "Comma-separated country codes, e.g. --countries=USA,DEU,GBR"
    arg_type = String
    "--countries-file"
    help = "Path to a file with comma or newline separated country codes"
    arg_type = String
    "--year"
    help = "Start and end year, e.g. --year=2010,2020"
    arg_type = String
    required = true
  end
  return parse_args(args, s)
end

function parse_countries_file(filepath::String)::Vector{String}
  return open(filepath, "r") do f
    content = read(f, String)
    return filter(!isempty, strip.(split(content, r"[,\n]+")))
  end
end

function resolve_countries(parsed::Dict)::Vector{String}
  has_list = !isnothing(parsed["countries"])
  has_file = !isnothing(parsed["countries-file"])

  if has_list && has_file
    error("Provide either --countries or --countries-file, not both")
  elseif has_list
    return filter(!isempty, strip.(split(parsed["countries"], ",")))
  elseif has_file
    return parse_countries_file(parsed["countries-file"])
  else
    error("Either --countries or --countries-file is required")
  end
end

function (@main)(args)
  parsed = parse_args_custom(args)

  countries = resolve_countries(parsed)
  years = parse.(Int, split(parsed["year"], ","))
  start_year, end_year = years[1], years[2]

  gdp_per_c_df = get_gdp_per_capita_dataframe()
  gdf = generate_growth_dataframe(gdp_per_c_df, start_year, end_year; included_countries=countries)
  plot_growth_rates(gdf)
  savefig("plot.png")
  print(regression(gdf))
  return nothing
end
